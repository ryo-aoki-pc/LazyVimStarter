#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";
import { text as readText } from "node:stream/consumers";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const runtimes = new Map();
const MAX_PASSES = 16;
const MAX_FIXES = 4096;

const parserOptions = {
  extension: {
    descriptionLists: true,
    table: true,
    strikethrough: true,
    autolink: true,
    tasklist: true,
    footnotes: true,
    multilineBlockQuotes: true,
    mathDollars: true,
    mathCode: true,
    alerts: true,
  },
  parse: { relaxedTasklistMatching: true, leaveFootnoteDefinitions: true },
};

const containers = new Set([
  "List", "Item", "TaskItem", "BlockQuote", "MultilineBlockQuote",
  "DescriptionList", "DescriptionItem", "DescriptionDetails", "DescriptionTerm",
  "FootnoteDefinition", "Table", "TableRow", "TableCell",
]);
const literalNodes = new Set([
  "Code", "CodeBlock", "Math", "HtmlBlock", "HtmlInline", "Raw",
  "MultilineBlockQuote", "FootnoteDefinition", "FootnoteReference", "TaskItem",
]);
const literalSpanTypes = new Set(["Code", "CodeBlock", "Math", "HtmlBlock", "HtmlInline"]);
const indentRules = new Set(["MD005", "MD007"]);

// 整形で直す修正の分類。名前は lang-markdown.lua の format_fixes と、CLI の --enable-fixes / --disable-fixes で使う。
// ルールごとの例は docs/reference/glfm-format.md にある。
export const fixCategories = Object.freeze({
  heading_spacing: ["MD019", "MD021", "MD023"],
  heading_conversion: ["MD018", "MD020"],
  heading_punctuation: ["MD026"],
  whitespace: ["MD009", "MD010", "MD047"],
  blank_lines: ["MD012", "MD022", "MD031", "MD032", "MD058"],
  lists: ["MD004", "MD005", "MD007", "MD029", "MD030"],
  blockquotes: ["MD027"],
  emphasis_style: ["MD049", "MD050"],
  emphasis_spaces: ["MD037"],
  code: ["MD014", "MD038"],
  link_style: ["MD034", "MD054"],
  link_text: ["MD039"],
  link_fragments: ["MD051"],
  reversed_links: ["MD011"],
  unused_definitions: ["MD053"],
  tables: ["MD060"],
  proper_names: ["MD044"],
});
// 既定では直さない分類 (見出し・強調・リンクを作る修正と、本文の行を消す修正)。
export const defaultDisabledCategories = Object.freeze(["heading_conversion", "emphasis_spaces", "reversed_links", "unused_definitions"]);
// markdownlint 0.41.1 の組み込みルールの別名。fixCategories に無いルールは自動修正を持たない (診断だけ)。
// ここに無い組み込みルール (markdownlint を上げて増えたもの) の修正は、確かめて表に足すまで当てない。
const ruleAliases = {
  MD001: ["heading-increment"], MD003: ["heading-style"], MD004: ["ul-style"], MD005: ["list-indent"],
  MD007: ["ul-indent"], MD009: ["no-trailing-spaces"], MD010: ["no-hard-tabs"], MD011: ["no-reversed-links"],
  MD012: ["no-multiple-blanks"], MD013: ["line-length"], MD014: ["commands-show-output"],
  MD018: ["no-missing-space-atx"], MD019: ["no-multiple-space-atx"], MD020: ["no-missing-space-closed-atx"],
  MD021: ["no-multiple-space-closed-atx"], MD022: ["blanks-around-headings"], MD023: ["heading-start-left"],
  MD024: ["no-duplicate-heading"], MD025: ["single-title", "single-h1"], MD026: ["no-trailing-punctuation"],
  MD027: ["no-multiple-space-blockquote"], MD028: ["no-blanks-blockquote"], MD029: ["ol-prefix"],
  MD030: ["list-marker-space"], MD031: ["blanks-around-fences"], MD032: ["blanks-around-lists"],
  MD033: ["no-inline-html"], MD034: ["no-bare-urls"], MD035: ["hr-style"], MD036: ["no-emphasis-as-heading"],
  MD037: ["no-space-in-emphasis"], MD038: ["no-space-in-code"], MD039: ["no-space-in-links"],
  MD040: ["fenced-code-language"], MD041: ["first-line-heading", "first-line-h1"], MD042: ["no-empty-links"],
  MD043: ["required-headings"], MD044: ["proper-names"], MD045: ["no-alt-text"], MD046: ["code-block-style"],
  MD047: ["single-trailing-newline"], MD048: ["code-fence-style"], MD049: ["emphasis-style"],
  MD050: ["strong-style"], MD051: ["link-fragments"], MD052: ["reference-links-images"],
  MD053: ["link-image-reference-definitions"], MD054: ["link-image-style"], MD055: ["table-pipe-style"],
  MD056: ["table-column-count"], MD058: ["blanks-around-tables"], MD059: ["descriptive-link-text"],
  MD060: ["table-column-style"],
};
export const builtinRuleNames = Object.freeze(Object.fromEntries(
  Object.entries(ruleAliases).map(([id, aliases]) => [id, Object.freeze([id, ...aliases])])));
const ruleCategories = new Map(Object.entries(fixCategories).flatMap(([category, ids]) => ids.map((id) => [id, category])));
const ruleIdsByAlias = new Map(Object.entries(ruleAliases).flatMap(([id, aliases]) => aliases.map((alias) => [alias, id])));
// 見出し・強調・リンクを作ることが目的の修正。構文木の比較では正しい修正と見分けられないので、緩い検査だけで当てる。
const creatingRules = new Set(["MD011", "MD018", "MD020", "MD037"]);
const headingConversionRules = new Set(["MD018", "MD020"]);
// 変えてよい差を限って構文木を比べる修正。その差だけを両方の木から消してから比べる。
const limitedRules = {
  // 見出しの末尾の句読点。
  MD026: (node) => (node[0] === "Heading" ? [node[0], node[1], editText(node[2], node[2].length - 1, (text) => text.replace(/[\p{P}\p{S}\s]+$/u, ""))] : node),
  // リンクの文字の端の ASCII の空白 (全角空白は比べる)。
  MD039: (node) => {
    if (node[0] !== "Link" && node[0] !== "Image") return node;
    const leading = editText(node[2], 0, (text) => text.replace(/^[ \t\r\n]+/u, ""));
    return [node[0], node[1], editText(leading, leading.length - 1, (text) => text.replace(/[ \t\r\n]+$/u, ""))];
  },
  // 文字の大文字小文字。
  MD044: (node) => (node[0] === "Text" ? ["Text", node[1].toLowerCase(), []] : node),
  // 同じ文書の見出しへのリンクの断片の大文字小文字。
  MD051: (node) => (node[0] === "Link" && node[1].url.startsWith("#") ? [node[0], { ...node[1], url: node[1].url.toLowerCase() }, node[2]] : node),
};
// Comrak に専用ノードが無い GitLab の記法。原文と出現順を変える修正は当てない。
// GitLab は [[_toc_]] のような小文字の目次も目次として描くので、大文字小文字を区別しない。
// 広めに当たっても検査が厳しくなるだけなので、参照は GitLab の規則より緩く拾う。
const gitlabAtoms = new RegExp([
  String.raw`\[\[_TOC_\]\]`, String.raw`\[TOC\]`, String.raw`\[~\]`, String.raw`\[\^[^\]\r\n]+\](?::)?`,
  // include は行頭から書いたときだけ働くので、その行の接頭辞ごと守る。
  String.raw`^[ \t>]*::include\{[^\r\n]*?\}`, String.raw`::include\{[^\r\n]*?\}`,
  String.raw`\{[+-][^\r\n]*?[+-]\}`, String.raw`\[[+-][^\r\n]*?[+-]\]`,
  // 画像と、直後の幅や高さの指定。
  String.raw`!\[[^\]\r\n]*\]\([^)\r\n]*\)\{[^}\r\n]*\}`,
  // 課題 #123・マージリクエスト !123・エピック &123・スニペット $123 (group/project#123 の形も)。
  String.raw`(?<![\w&])(?:[\w.-]+(?:\/[\w.-]+)+)?[#!&$]\d+(?:\+s?)?`,
  // ラベル ~label・~"label"、マイルストーン %milestone・%"milestone"、ユーザー @user。
  String.raw`(?<![\w~])~(?:"[^"\r\n]+"|[\p{L}\p{N}_][\p{L}\p{N}_.?&-]*)`,
  String.raw`(?<![\w%])%(?:"[^"\r\n]+"|[\p{L}\p{N}_][\p{L}\p{N}_.-]*)`,
  String.raw`(?<![\w.+@-])@[\p{L}\p{N}_][\p{L}\p{N}_.-]*`,
].join("|"), "gimu");

async function runtime(directory) {
  const resolved = path.resolve(directory);
  if (!runtimes.has(resolved)) {
    runtimes.set(resolved, (async () => {
      const require = createRequire(path.join(resolved, "package.json"));
      const { main } = await import(pathToFileURL(require.resolve("markdownlint-cli2")));
      const { parseMarkdown } = require("comrak");
      if (typeof main !== "function" || typeof parseMarkdown !== "function") {
        throw new Error("整形ツールの依存パッケージを読み込めません。");
      }
      return { main, parseMarkdown };
    })().catch((error) => {
      runtimes.delete(resolved);
      throw error;
    }));
  }
  return runtimes.get(resolved);
}

function nodeType(node) {
  const value = node.data.value;
  return typeof value === "string" ? value : Object.keys(value)[0];
}

function nodeValue(node) {
  const type = nodeType(node);
  const value = typeof node.data.value === "string" ? null : node.data.value[type];
  // 位置やマーカーの表記は比較せず、表示内容と構造に関わる値だけを残す。
  if (type === "List" || type === "Item") {
    return {
      list_type: value.list_type,
      ...(type === "List" ? { start: value.start } : {}),
      tight: value.tight,
      is_task_list: value.is_task_list,
    };
  }
  if (type === "DescriptionItem") return { tight: value.tight };
  if (type === "CodeBlock") return { literal: value.literal, info: value.info };
  if (type === "Code") return { literal: value.literal };
  if (type === "Heading") return { level: value.level };
  if (type === "Link" || type === "Image") return { url: value.url, title: value.title };
  if (type === "Table") return { alignments: value.alignments };
  if (type === "Alert") return { alert_type: value.alert_type, title: value.title ?? null, multiline: value.multiline };
  if (type === "MultilineBlockQuote") return null;
  if (type === "FootnoteDefinition" || type === "FootnoteReference") return { name: value.name };
  return value;
}

function editText(children, index, edit) {
  if (children[index]?.[0] !== "Text") return children;
  const text = edit(children[index][1]);
  const edited = [...children];
  if (text) edited[index] = ["Text", text, []];
  else edited.splice(index, 1);
  return edited;
}

function mapTree(tree, change) {
  const [type, value, children] = change(tree);
  return [type, value, children.map((child) => mapTree(child, change))];
}

function childIndices(nodes, index) {
  const children = [];
  for (let child = nodes[index].first_child; child !== undefined; child = nodes[child].next_sibling) {
    children.push(child);
  }
  return children;
}

// 表示に関わる構造の木。隣り合う Text と SoftBreak は 1 つの文字列にし、HTML で同じに見える
// ASCII の空白・タブ・改行の並びだけを空白 1 つに畳む。全角空白や NBSP は畳まず、要素の端の空白も残す。
function canonicalNode(nodes, index) {
  const children = [];
  let text = null;
  const flush = () => {
    if (text !== null) children.push(["Text", text.replace(/[ \t\r\n]+/gu, " "), []]);
    text = null;
  };
  for (const child of childIndices(nodes, index)) {
    const type = nodeType(nodes[child]);
    if (type === "Text" || type === "SoftBreak") {
      text = (text ?? "") + (type === "Text" ? nodes[child].data.value.Text : "\n");
    } else {
      flush();
      children.push(canonicalNode(nodes, child));
    }
  }
  flush();
  return [nodeType(nodes[index]), nodeValue(nodes[index]), children];
}

function containerPath(nodes, index) {
  const result = [];
  for (let parent = nodes[index].parent; parent !== undefined; parent = nodes[parent].parent) {
    const type = nodeType(nodes[parent]);
    if (!containers.has(type)) continue;
    let ordinal = 0;
    for (let sibling = nodes[parent].previous_sibling; sibling !== undefined; sibling = nodes[sibling].previous_sibling) {
      if (nodeType(nodes[sibling]) === type) ordinal++;
    }
    result.push([type, nodeValue(nodes[parent]), ordinal]);
  }
  return result.reverse();
}

function linesOf(source) {
  const lines = [];
  const expression = /([^\r\n]*)(\r\n|\r|\n|$)/gu;
  for (const match of source.matchAll(expression)) {
    lines.push({ start: match.index, content: match[1], ending: match[2] });
  }
  return lines;
}

function frontMatter(source, lines) {
  const opening = /^(---|\+\+\+|;;;)[\w.+-]*[ \t]*$/u.exec(lines[0]?.content.replace(/^\uFEFF/u, "") || "");
  if (!opening) return null;
  for (let line = 1; line < lines.length; line++) {
    if (lines[line].content.trimEnd() === opening[1]) {
      const end = lines[line].start + lines[line].content.length + lines[line].ending.length;
      return { end, raw: source.slice(0, end) };
    }
  }
  return null;
}

// Comrak の列は UTF-8 のバイト数、JavaScript と fixInfo の列は UTF-16。
function sourceOffset(source, lines, position, inclusive) {
  const line = lines[position.line - 1];
  if (!line) return source.length;
  const bytes = Math.max(0, position.column - (inclusive ? 0 : 1));
  return line.start + Buffer.from(line.content).subarray(0, bytes).toString("utf8").length;
}

function sourceSlice(source, lines, sourcepos) {
  if (!sourcepos?.start.line || !sourcepos?.end.line) return "";
  return source.slice(sourceOffset(source, lines, sourcepos.start, false), sourceOffset(source, lines, sourcepos.end, true));
}

function projection(source, parseMarkdown) {
  const lines = linesOf(source);
  const matter = frontMatter(source, lines);
  const parsed = matter ? matter.raw.replace(/[^\r\n]/gu, " ") + source.slice(matter.end) : source;
  const { nodes } = parseMarkdown(parsed, parserOptions);
  const replacements = [];
  const blankRequests = [];
  const itemLists = new Map();
  // 見立てた行ごとの、元の行の本来の接頭辞 (見立てた部分より前)。
  const realPrefixes = new Map();
  // コードや数式などの中身と GitLab の記法の範囲。ここに掛かる修正は 1 つずつ確かめる。
  const protectedSpans = [...source.matchAll(gitlabAtoms)].map((match) => [match.index, match.index + match[0].length]);
  const headingRows = new Set();
  for (let index = 0; index < nodes.length; index++) {
    const node = nodes[index];
    const type = nodeType(node);
    const position = node.data.sourcepos?.start;
    if (!position || !lines[position.line - 1]) continue;
    const line = lines[position.line - 1];
    const column = Buffer.from(line.content).subarray(0, position.column - 1).toString("utf8").length;
    if (literalSpanTypes.has(type) && node.data.sourcepos.end?.line) {
      protectedSpans.push([
        sourceOffset(source, lines, position, false),
        sourceOffset(source, lines, node.data.sourcepos.end, true),
      ]);
    }
    if (type === "Heading") {
      for (let row = position.line; row <= (node.data.sourcepos.end?.line || position.line); row++) headingRows.add(row);
    }
    if (type === "DescriptionDetails" && /[:~]/u.test(line.content[column] || "")) {
      const item = nodes[node.parent]?.data.value.DescriptionItem;
      const marker = /^[:~][ \t]+/u.exec(line.content.slice(column));
      const offset = item?.marker_offset || 0;
      const base = column - offset;
      if (marker && base >= 0 && /^ *$/u.test(line.content.slice(base, column))) {
        const width = offset + marker[0].length;
        // 説明を同じ幅の引用として見せる。架空のリスト階層を作らず sublist の意味を保つ。
        const prefix = "> ".repeat(Math.floor(width / 2)) + (width % 2 ? " " : "");
        replacements.push({ start: line.start + base, width, prefix });
        realPrefixes.set(position.line, { text: line.content.slice(0, base), base });
        for (let row = position.line + 1; row <= node.data.sourcepos.end.line; row++) {
          const continuation = lines[row - 1];
          if (continuation && /^(?:[ \t]*>)*[ \t]*$/u.test(continuation.content)) {
            blankRequests.push({ row, markerRow: position.line, markerEnd: base + width });
          } else if (continuation && continuation.content.length >= base + width &&
              /^ +$/u.test(continuation.content.slice(base, base + width))) {
            replacements.push({ start: continuation.start + base, width, prefix });
            realPrefixes.set(row, { text: continuation.content.slice(0, base), base });
          }
        }
      }
    }
    if ((type === "Item" || type === "TaskItem") && node.parent !== undefined && nodeType(nodes[node.parent]) === "List") {
      itemLists.set(`${position.line}:${column + 1}`, node.parent);
    }
  }
  let projected = source;
  for (const { start, width, prefix } of replacements.sort((a, b) => b.start - a.start)) {
    projected = projected.slice(0, start) + prefix + projected.slice(start + width);
  }
  // 空行も引用の中に置き、段落間の空行で本物の子リストが分裂して見えるのを防ぐ。
  // この行だけ幅が変わるため、空行に対する診断は元の解析結果だけを使う。
  const projectedLines = linesOf(projected);
  const blankPrefixes = new Map();
  for (const { row, markerRow, markerEnd } of blankRequests) {
    const prefix = projectedLines[markerRow - 1].content.slice(0, markerEnd).trimEnd();
    if (prefix.length > (blankPrefixes.get(row)?.length || 0)) blankPrefixes.set(row, prefix);
  }
  const projectedRows = new Set(realPrefixes.keys());
  for (const [row, prefix] of [...blankPrefixes].sort((a, b) => b[0] - a[0])) {
    const original = lines[row - 1];
    projected = projected.slice(0, original.start) + prefix + projected.slice(original.start + original.content.length);
    realPrefixes.set(row, { text: original.content, base: original.content.length });
  }
  return {
    source: projected, lines, itemLists, projectedRows, realPrefixes, protectedSpans, headingRows,
    syntheticBlankRows: new Set(blankPrefixes.keys()),
  };
}

// 引用に見立てた行では、markdownlint が空行を足すときに見立ての > まで写す。そのまま元の文書に
// 当てると空の引用ができるので、足す行を元の行の本来の接頭辞に戻す。
// MD027 (> の後の空白) も、見立てた部分では説明の字下げを指すだけなので当てない。
function fromProjection(fix, projected) {
  const [row, column] = fixPosition(fix);
  const own = projected.realPrefixes.get(row);
  if (fix.ruleNames[0] === "MD027" && own && column - 1 >= own.base) return null;
  const text = fix.fixInfo.insertText;
  if (!text || !text.includes("\n")) return fix;
  const source = [row - 1, row].find((candidate) => projected.realPrefixes.has(candidate));
  if (source === undefined) return fix;
  const raw = projected.realPrefixes.get(source).text.replace(/[^>]/gu, " ");
  const prefix = fix.ruleNames[0] === "MD031" ? raw.trim() : raw.trimEnd();
  const lines = text.split("\n");
  const insertText = lines.map((line, index) => (index < lines.length - 1 && /^[> \t]*$/u.test(line) ? prefix : line)).join("\n");
  return { ...fix, fixInfo: { ...fix.fixInfo, insertText } };
}

// コードや数式などの中身か、GitLab の記法に掛かる修正か。
function touchesProtected(fix, projected) {
  const [row, column] = fixPosition(fix);
  const line = projected.lines[row - 1];
  if (!line) return false;
  const count = fix.fixInfo.deleteCount || 0;
  const start = count === -1 ? line.start : line.start + column - 1;
  const end = count === -1 ? line.start + line.content.length + line.ending.length : start + Math.max(0, count);
  return projected.protectedSpans.some(([from, to]) => (end > start ? start < to && end > from : from < start && start < to));
}

function ruleId(fix) {
  return fix.ruleNames[0].toUpperCase();
}

// 修正の確かめ方。layout は構文木の全体を、ルール名は変えてよい差を消してから比べる。creating は緩い検査だけ。
// カスタムルールは本文を変えることもあるので、今までどおり緩い検査だけで当てる。
function fixMode(fix) {
  const id = ruleId(fix);
  if (!Object.hasOwn(ruleAliases, id) || creatingRules.has(id)) return "creating";
  return Object.hasOwn(limitedRules, id) ? id : "layout";
}

// 名前を分類・組み込みルール・カスタムルールのどれかに決める。
function fixTarget(name) {
  if (Object.hasOwn(fixCategories, name)) return `category:${name}`;
  const id = name.toUpperCase();
  if (Object.hasOwn(ruleAliases, id)) return `rule:${id}`;
  if (ruleIdsByAlias.has(name.toLowerCase())) return `rule:${ruleIdsByAlias.get(name.toLowerCase())}`;
  // 分類名やルール名の綴り違いを、カスタムルールの名前として黙って受け取らない。
  if (/^MD\d+$/iu.test(name) || /^[a-z_]+$/u.test(name)) {
    throw new Error(`整形する対象 ${name} は、分類名にもルール名にもありません。`);
  }
  return `custom:${name.toLowerCase()}`;
}

function fixSelector(fixes) {
  if (fixes !== undefined && fixes !== null && (typeof fixes !== "object" || Array.isArray(fixes))) {
    throw new TypeError("整形する対象は、名前を真偽値に対応させた表にしてください。");
  }
  const chosen = new Map();
  for (const [name, enabled] of Object.entries(fixes || {})) {
    if (typeof enabled !== "boolean") throw new TypeError(`整形する対象 ${name} は true か false にしてください。`);
    const target = fixTarget(name);
    if (chosen.has(target) && chosen.get(target) !== enabled) {
      throw new Error(`整形する対象 ${name} を、有効と無効の両方に指定しています。`);
    }
    chosen.set(target, enabled);
  }
  // ルール名の指定 > 分類の指定 > 既定。
  return (fix) => {
    const id = ruleId(fix);
    if (Object.hasOwn(ruleAliases, id)) {
      if (chosen.has(`rule:${id}`)) return chosen.get(`rule:${id}`);
      const category = ruleCategories.get(id);
      if (!category) return false;
      return chosen.get(`category:${category}`) ?? !defaultDisabledCategories.includes(category);
    }
    // 表に無い組み込みルールの修正は、確かめるまで当てない。
    if (/^MD\d+$/u.test(id)) return false;
    const custom = fix.ruleNames.find((name) => chosen.has(`custom:${name.toLowerCase()}`));
    return custom === undefined ? true : chosen.get(`custom:${custom.toLowerCase()}`);
  };
}

// 見出しにする修正 (MD018・MD020) を当ててよい行か。
function convertibleHeading(fix, projected, selection) {
  if (!headingConversionRules.has(ruleId(fix))) return true;
  const [row] = fixPosition(fix);
  const line = projected.lines[row - 1];
  // GitLab の課題の参照 (#123) と、既にある見出し (# C# など) は見出しにしない。
  if (!line || /^#+\d/u.test(line.content) || projected.headingRows.has(row)) return false;
  // 範囲整形では、見出しになる文字 (行末の空白を除く) が全部選択に入っているときだけ見出しにする。
  return !selection || line.start + line.content.trimEnd().length <= selection.end;
}

function semanticSnapshot(source, parseMarkdown) {
  const lines = linesOf(source);
  const matter = frontMatter(source, lines);
  // メタデータ中の見本を説明リストとして解析しない。閉じていない区切りは本文扱い。
  const parsedSource = matter
    ? matter.raw.replace(/[^\r\n]/gu, " ") + source.slice(matter.end)
    : source;
  const { nodes } = parseMarkdown(parsedSource, parserOptions);
  if (!Array.isArray(nodes) || !nodes.length) throw new Error("Markdown を解析できません。");
  const descriptions = [];
  const literals = [];
  for (let index = 0; index < nodes.length; index++) {
    const type = nodeType(nodes[index]);
    if (type === "DescriptionList") {
      // 入れ子を含む全項目を比較し、親の引用やリストからの移動も検出する。
      descriptions.push([containerPath(nodes, index), canonicalNode(nodes, index)]);
    }
    if (literalNodes.has(type)) {
      literals.push([containerPath(nodes, index), canonicalNode(nodes, index),
        type === "Math" ? sourceSlice(source, lines, nodes[index].data.sourcepos) : null]);
    }
  }
  const atoms = [...source.matchAll(gitlabAtoms)].map((match) => match[0]);
  // loose (緩い検査) は最初の文書と比べ続ける。tree (構文木の全体) は、受け付けた文書ごとに取り直す。
  return {
    loose: JSON.stringify({ frontMatter: matter?.raw || null, descriptions, literals, atoms }),
    tree: canonicalNode(nodes, 0),
  };
}

function preferredEnding(source) {
  const counts = new Map();
  for (const [ending] of source.matchAll(/\r\n|\r|\n/gu)) counts.set(ending, (counts.get(ending) || 0) + 1);
  return [...counts].sort((a, b) => b[1] - a[1])[0]?.[0] || "\n";
}

function fixPosition(error) {
  return [error.fixInfo.lineNumber || error.lineNumber, error.fixInfo.editColumn || 1];
}

function applyFix(source, error) {
  const fix = error.fixInfo;
  const [lineNumber, column] = fixPosition(error);
  const lines = linesOf(source);
  const line = lines[lineNumber - 1];
  if (!line) throw new Error("整形ツールが不正な修正位置を返しました。");
  const start = line.start + column - 1;
  const count = fix.deleteCount || 0;
  if (column < 1 || column > line.content.length + 1 || count < -1 ||
      (count !== -1 && column - 1 + count > line.content.length)) {
    throw new Error("整形ツールが不正な修正範囲を返しました。");
  }
  if (count === -1) {
    // 改行の無い最後の行は、前の行の改行ごと消す (markdownlint が行を結合し直すのと同じ)。
    // そうしないと、末尾の余分な空行を消す MD012 の修正が何も変えない。
    if (!line.ending && lineNumber > 1) {
      const previous = lines[lineNumber - 2];
      return source.slice(0, previous.start + previous.content.length) + source.slice(line.start + line.content.length);
    }
    return source.slice(0, line.start) + source.slice(line.start + line.content.length + line.ending.length);
  }
  const insertion = (fix.insertText || "").replace(/\n/gu, preferredEnding(source));
  return source.slice(0, start) + insertion + source.slice(start + count);
}

async function lint(source, { main }, { filename, cwd, config }) {
  let results = [];
  const errors = [];
  const argv = [`:${filename}`];
  if (typeof config === "string") argv.push("--config", path.resolve(cwd, config));
  // プロジェクト設定とインライン設定の読み込みは CLI2 に任せる。
  // fix と出力フォーマッターだけを上書きし、ファイルへの書き込みを禁止する。
  const readOnlyFs = {
    ...fs,
    promises: {
      ...fs.promises,
      writeFile: async () => { throw new Error("整形処理からファイルには書き込めません。"); },
    },
  };
  let status;
  try {
    status = await main({
      directory: cwd,
      argv,
      noGlobs: true,
      fileContents: { [filename]: source },
      fs: readOnlyFs,
      optionsDefault: typeof config === "object" && config !== null ? { config } : undefined,
      optionsOverride: {
        fix: false,
        noBanner: true,
        noProgress: true,
        outputFormatters: [[({ results: captured }) => { results = captured; }]],
      },
      logMessage() {},
      logError(message) { errors.push(message); },
    });
  } catch (error) {
    throw new Error(`Markdownlint の設定またはルールを読み込めません: ${String(error.message).split(/[\r\n]/u)[0]}`, { cause: error });
  }
  if (errors.length) throw new Error("Markdownlint の設定またはルールを読み込めません。");
  if (status !== 0 && status !== 1) throw new Error("Markdownlint の設定を読み込めません。");
  if (results.some((result) => result.errorDetail?.startsWith("This rule threw an exception:"))) {
    throw new Error("Markdownlint のルール実行に失敗しました。");
  }
  // Windows のドライブ文字の大小が違っても同じファイルと見なす。
  return results.filter((result) => result.fixInfo && path.relative(path.resolve(cwd, result.fileName), filename) === "");
}

function isInside(directory, file) {
  const relative = path.relative(directory, file);
  return relative !== "" && !path.isAbsolute(relative) && relative.split(/[\\/]/u)[0] !== "..";
}

function selectedRange(source, range) {
  if (!range) return null;
  const lines = linesOf(source);
  const boundary = (position, inclusive) => {
    const line = lines[position[0] - 1];
    if (!line) return source.length;
    const bytes = Buffer.from(line.content);
    let column = position[1] ?? (inclusive ? Infinity : 0);
    if (!Number.isFinite(column)) return line.start + line.content.length;
    column = Math.min(bytes.length, Math.max(0, column + (inclusive ? 1 : 0)));
    if (inclusive) {
      // Neovim の終点が文字の先頭バイトでも、選択した文字全体を含める。
      while (column < bytes.length && (bytes[column] & 0xc0) === 0x80) column++;
    } else {
      while (column > 0 && (bytes[column] & 0xc0) === 0x80) column--;
    }
    return line.start + bytes.subarray(0, column).toString("utf8").length;
  };
  return { start: boundary(range.start, false), end: boundary(range.end, true) };
}

function inRange(source, fix, selection) {
  if (!selection) return true;
  const lines = linesOf(source);
  const [row, column] = fixPosition(fix);
  const line = lines[row - 1];
  if (!line) return false;
  // fixInfo は UTF-16 なので、変換済みの選択範囲と直接比較できる。
  let fixStart = line.start + column - 1;
  let fixEnd = fixStart + Math.max(0, fix.fixInfo.deleteCount || 0);
  if (fix.fixInfo.deleteCount === -1 || /\r|\n/u.test(fix.fixInfo.insertText || "")) {
    fixStart = line.start;
    fixEnd = line.start + line.content.length + line.ending.length;
  }
  return fixStart >= selection.start && fixEnd <= selection.end &&
    (fix.fixInfo.deleteCount || fixStart < selection.end);
}

function fixGroups(fixes, itemLists) {
  const groups = [];
  const markerGroups = new Map();
  const unique = new Set();
  for (const fix of fixes) {
    const key = JSON.stringify([fixPosition(fix), fix.fixInfo]);
    if (unique.has(key)) continue;
    unique.add(key);
    const [line, column] = fixPosition(fix);
    const list = itemLists.get(`${line}:${column}`);
    // 記号 (MD004) と番号 (MD029) は、リストごとにまとめて当てるか見送る。1 項目めの番号だけ見送ると、
    // 開始番号は保てても `3. 2. 3.` のような番号が残る。
    const marker = (ruleId(fix) === "MD004" && /^[*+-]$/u.test(fix.fixInfo.insertText || "")) ||
      (ruleId(fix) === "MD029" && /^\d+$/u.test(fix.fixInfo.insertText || ""));
    if (marker && list !== undefined && fix.fixInfo.deleteCount >= 1) {
      const key = `${ruleId(fix)}:${list}`;
      if (!markerGroups.has(key)) {
        const group = [];
        markerGroups.set(key, group);
        groups.push(group);
      }
      markerGroups.get(key).push(fix);
    } else {
      groups.push([fix]);
    }
  }
  const descending = (a, b) => {
    const [aLine, aColumn] = fixPosition(a);
    const [bLine, bColumn] = fixPosition(b);
    return bLine - aLine || bColumn - aColumn || Number(a.fixInfo.deleteCount === -1) - Number(b.fixInfo.deleteCount === -1);
  };
  groups.forEach((group) => group.sort(descending));
  return groups.sort((a, b) => descending(a[0], b[0]));
}

export async function formatMarkdown(source, options = {}) {
  if (typeof source !== "string") throw new TypeError("Markdown の入力は文字列にしてください。");
  if (!options.filename || !path.isAbsolute(options.filename)) {
    throw new Error("整形対象の絶対ファイル名を指定してください。");
  }
  const filename = path.normalize(options.filename);
  const settings = { ...options, filename, cwd: path.resolve(options.cwd || path.dirname(filename)) };
  if (options.range && (!Array.isArray(options.range.start) || !Array.isArray(options.range.end) ||
      !Number.isInteger(options.range.start[0]) || !Number.isInteger(options.range.end[0]) ||
      options.range.start[0] < 1 || options.range.end[0] < options.range.start[0] ||
      (options.range.start[1] !== undefined && (!Number.isInteger(options.range.start[1]) || options.range.start[1] < 0)) ||
      (options.range.end[1] !== undefined && options.range.end[1] !== Infinity &&
       (!Number.isInteger(options.range.end[1]) || options.range.end[1] < -1)))) {
    throw new Error("整形範囲の行または列番号が不正です。");
  }
  const selection = selectedRange(source, options.range);
  if (selection && selection.end < selection.start) throw new Error("整形範囲の開始と終了が逆です。");
  const selected = fixSelector(options.fixes);
  const dependencies = await runtime(options.runtimeDir || scriptDirectory);
  const original = semanticSnapshot(source, dependencies.parseMarkdown);
  const originalSnapshot = original.loose;
  // 構文木の全体は、最後に受け付けた文書と比べる (見出しなどを作る修正の後も、その先の修正を確かめられる)。
  let currentTree = original.tree;
  let currentKeys = new Map();
  const structureKey = (tree, mode) => JSON.stringify(Object.hasOwn(limitedRules, mode) ? mapTree(tree, limitedRules[mode]) : tree);
  const currentKey = (mode) => {
    if (!currentKeys.has(mode)) currentKeys.set(mode, structureKey(currentTree, mode));
    return currentKeys.get(mode);
  };
  const visited = new Set([source]);
  let current = source;
  let attempted = 0;
  for (let pass = 0; pass < MAX_PASSES; pass++) {
    const projected = projection(current, dependencies.parseMarkdown);
    let fixes = await lint(current, dependencies, settings);
    if (projected.source !== current) {
      // リストの表記は正しい階層を持つ引用版を基準とし、元の解析との往復を防ぐ。
      // 説明の中の行の字下げ (MD005 / MD007) も引用版だけで見る。元の解析は説明リストを知らず、
      // その修正は必ず却下されるので、保存のたびに検証の手間だけが掛かる。
      fixes = fixes.filter((fix) => fix.ruleNames[0] !== "MD004" &&
        !(indentRules.has(fix.ruleNames[0]) && projected.projectedRows.has(fixPosition(fix)[0])));
      fixes.push(...(await lint(projected.source, dependencies, settings))
        .filter((fix) => !projected.syntheticBlankRows.has(fixPosition(fix)[0]))
        .map((fix) => fromProjection(fix, projected))
        .filter(Boolean));
    }
    // 選ばれていない修正と、見出しにしてはいけない行の修正は、まとめを作る前に外す。
    fixes = fixes.filter((fix) => selected(fix) && convertibleHeading(fix, projected, selection));
    // 範囲で先に絞ると、通常のリストでも一部のマーカーだけが変わって分裂する。
    const groups = fixGroups(fixes, projected.itemLists)
      .filter((group) => group.every((fix) => inRange(current, fix, selection)));
    // 検証は文書全体を Comrak で解析し直すので、修正ごとに確かめると長い文書で保存の上限を超える。
    // まとめて当てて 1 回で確かめ、構造が変わるときだけ半分に分けて原因の修正を除く。
    // まとめは下の行から並んでいるので、どの部分を当てても残りの修正位置はずれない。
    // 同じリストのマーカー変更は 1 つのまとめのまま扱い、途中の混在でリストが分裂するのを避ける。
    // 緩い検査 (説明リスト・リテラル・GitLab の記法) は常に最初の文書と、構文木の全体は今の文書と比べる。
    const accept = (batch, mode) => {
      if (!batch.length) return;
      const candidate = batch.flat().reduce((value, fix) => applyFix(value, fix), current);
      if (candidate === current) return;
      const snapshot = semanticSnapshot(candidate, dependencies.parseMarkdown);
      if (snapshot.loose === originalSnapshot &&
          (mode === "creating" || structureKey(snapshot.tree, mode) === currentKey(mode))) {
        // 範囲内の改行増減に追従し、次の解析で元の選択範囲外を整形しない。
        if (selection) selection.end += candidate.length - current.length;
        current = candidate;
        currentTree = snapshot.tree;
        currentKeys = new Map();
        return;
      }
      if (batch.length === 1) return;
      const middle = Math.ceil(batch.length / 2);
      accept(batch.slice(0, middle), mode);
      accept(batch.slice(middle), mode);
    };
    let changed = false;
    let pending = groups;
    while (pending.length && !changed) {
      const batch = [];
      const deferred = [];
      const selectedRanges = [];
      for (const group of pending) {
        const ranges = group.map((fix) => {
          const [line, column] = fixPosition(fix);
          return { line, column, end: column + Math.max(0, fix.fixInfo.deleteCount || 0), deleted: fix.fixInfo.deleteCount === -1 };
        });
        // 同じ解析結果に基づく重複修正は同時に当てない。ほかが当たれば次の解析で再評価し、
        // 何も当たらなかったときは、位置がずれていないのでこのまま残りを試す。
        if (ranges.some((candidate) => selectedRanges.some((range) => range.line === candidate.line &&
            (candidate.deleted || range.deleted || (candidate.end > range.column && candidate.column < range.end) ||
             candidate.column === range.column)))) {
          deferred.push(group);
          continue;
        }
        attempted += group.length;
        if (attempted > MAX_FIXES) throw new Error("修正が多すぎるため整形を中止しました。");
        selectedRanges.push(...ranges);
        batch.push(group);
      }
      const before = current;
      // コードや数式の中身と GitLab の記法を変える修正は、ほとんど却下される。まとめに混ぜると半分に分ける検証が
      // 増えるので、前後のまとめと順番を保ったまま 1 つずつ確かめる (結果は同じで、手間だけが減る)。
      // 確かめ方の違う修正も、順番を保ったまま別のまとめにする。
      let run = [];
      let runMode;
      const flush = () => {
        accept(run, runMode);
        run = [];
      };
      for (const group of batch) {
        const mode = fixMode(group[0]);
        if (group.some((fix) => touchesProtected(fix, projected))) {
          flush();
          accept([group], mode);
        } else {
          if (run.length && mode !== runMode) flush();
          runMode = mode;
          run.push(group);
        }
      }
      flush();
      changed = current !== before;
      pending = deferred;
    }
    if (!changed) {
      if (semanticSnapshot(current, dependencies.parseMarkdown).loose !== originalSnapshot) {
        throw new Error("説明リストの構造を保持できませんでした。");
      }
      return current;
    }
    if (visited.has(current)) throw new Error("整形結果が収束しないため中止しました。");
    visited.add(current);
  }
  throw new Error("整形結果が収束しないため中止しました。");
}

async function cli() {
  const options = {};
  const names = new Map([["--runtime-dir", "runtimeDir"], ["--filename", "filename"], ["--config", "config"],
    ["--range-start", "rangeStart"], ["--range-end", "rangeEnd"],
    ["--range-start-column", "rangeStartColumn"], ["--range-end-column", "rangeEndColumn"],
    ["--enable-fixes", "enableFixes"], ["--disable-fixes", "disableFixes"]]);
  const arguments_ = process.argv.slice(2);
  for (let index = 0; index < arguments_.length; index++) {
    const name = names.get(arguments_[index]);
    if (!name || !arguments_[index + 1] || arguments_[index + 1].startsWith("--")) {
      throw new Error("引数は --runtime-dir、--filename、--config、--range-*、--enable-fixes、--disable-fixes を指定してください。");
    }
    if (options[name] !== undefined) throw new Error("同じ引数を複数回指定できません。");
    options[name] = arguments_[++index];
  }
  if (!options.runtimeDir) throw new Error("--runtime-dir を指定してください。");
  // --enable-fixes と --disable-fixes は、カンマ区切りの分類名かルール名。同じ名前を両方に書くと、整形の API が拒む。
  for (const [name, enabled] of [["enableFixes", true], ["disableFixes", false]]) {
    if (options[name] === undefined) continue;
    options.fixes ||= {};
    for (const fix of options[name].split(",").map((value) => value.trim())) {
      if (!fix) throw new Error("整形する対象の名前が空です。");
      if (Object.hasOwn(options.fixes, fix) && options.fixes[fix] !== enabled) {
        throw new Error(`整形する対象 ${fix} を、有効と無効の両方に指定しています。`);
      }
      options.fixes[fix] = enabled;
    }
  }
  // conform は Neovim の作業ディレクトリでこのスクリプトを起動する。以前の markdownlint-cli2 --fix と
  // 同じく、ファイルがその下にあればそこを CLI2 の基準にし、上の階層のプロジェクト設定も読ませる。
  if (options.filename && path.isAbsolute(options.filename) && isInside(process.cwd(), options.filename)) {
    options.cwd = process.cwd();
  }
  if (options.rangeStart !== undefined || options.rangeEnd !== undefined ||
      options.rangeStartColumn !== undefined || options.rangeEndColumn !== undefined) {
    if (!options.rangeStart || !options.rangeEnd) throw new Error("範囲の開始行と終了行を指定してください。");
    options.range = {
      start: [Number(options.rangeStart), options.rangeStartColumn === undefined ? 0 : Number(options.rangeStartColumn)],
      end: [Number(options.rangeEnd), options.rangeEndColumn === undefined ? Infinity : Number(options.rangeEndColumn)],
    };
  }
  const output = await formatMarkdown(await readText(process.stdin), options);
  process.stdout.write(output);
}

// Node は実体のパスで読み込むので、シンボリックリンクやジャンクションを通った起動も実体で比べる。
// 一致しないと何も出力せずに終わり、conform は空の出力として黙って整形をやめる。
function isMainScript() {
  if (!process.argv[1]) return false;
  try {
    return fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (isMainScript()) {
  cli().catch((error) => {
    const detail = error?.message?.split(/[\r\n]/u)[0] || "不明なエラー";
    process.stderr.write(`GitLab Markdown の整形に失敗しました: ${detail}\n`);
    process.exitCode = 1;
  });
}
