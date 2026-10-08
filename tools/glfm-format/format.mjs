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
  if (type === "Heading") return { level: value.level };
  if (type === "MultilineBlockQuote") return null;
  if (type === "FootnoteDefinition" || type === "FootnoteReference") return { name: value.name };
  return value;
}

function childIndices(nodes, index) {
  const children = [];
  for (let child = nodes[index].first_child; child !== undefined; child = nodes[child].next_sibling) {
    children.push(child);
  }
  return children;
}

function canonicalNode(nodes, index) {
  return [nodeType(nodes[index]), nodeValue(nodes[index]),
    childIndices(nodes, index).map((child) => canonicalNode(nodes, child))];
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

function sourceSlice(source, lines, sourcepos) {
  if (!sourcepos?.start.line || !sourcepos?.end.line) return "";
  // Comrak の列は UTF-8 のバイト数、JavaScript と fixInfo の列は UTF-16。
  const offset = (position, inclusive) => {
    const line = lines[position.line - 1];
    if (!line) return source.length;
    const bytes = Math.max(0, position.column - (inclusive ? 0 : 1));
    return line.start + Buffer.from(line.content).subarray(0, bytes).toString("utf8").length;
  };
  return source.slice(offset(sourcepos.start, false), offset(sourcepos.end, true));
}

function projection(source, parseMarkdown) {
  const lines = linesOf(source);
  const matter = frontMatter(source, lines);
  const parsed = matter ? matter.raw.replace(/[^\r\n]/gu, " ") + source.slice(matter.end) : source;
  const { nodes } = parseMarkdown(parsed, parserOptions);
  const replacements = [];
  const blankRequests = [];
  const itemLists = new Map();
  for (let index = 0; index < nodes.length; index++) {
    const node = nodes[index];
    const type = nodeType(node);
    const position = node.data.sourcepos?.start;
    if (!position || !lines[position.line - 1]) continue;
    const line = lines[position.line - 1];
    const column = Buffer.from(line.content).subarray(0, position.column - 1).toString("utf8").length;
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
        for (let row = position.line + 1; row <= node.data.sourcepos.end.line; row++) {
          const continuation = lines[row - 1];
          if (continuation && /^(?:[ \t]*>)*[ \t]*$/u.test(continuation.content)) {
            blankRequests.push({ row, markerRow: position.line, markerEnd: base + width });
          } else if (continuation && continuation.content.length >= base + width &&
              /^ +$/u.test(continuation.content.slice(base, base + width))) {
            replacements.push({ start: continuation.start + base, width, prefix });
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
  for (const [row, prefix] of [...blankPrefixes].sort((a, b) => b[0] - a[0])) {
    const original = lines[row - 1];
    projected = projected.slice(0, original.start) + prefix + projected.slice(original.start + original.content.length);
  }
  return { source: projected, itemLists, syntheticBlankRows: new Set(blankPrefixes.keys()) };
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
  // Comrak に専用ノードがない GitLab の記法も、原文と出現順を保つ。
  const atoms = [...source.matchAll(/\[\[_TOC_\]\]|\[TOC\]|\[~\]|\[\^[^\]\r\n]+\](?::)?|::include\{[^\r\n]*?\}|\{[+-][^\r\n]*?[+-]\}|\[[+-][^\r\n]*?[+-]\]/gu)]
    .map((match) => match[0]);
  return JSON.stringify({ frontMatter: matter?.raw || null, descriptions, literals, atoms });
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
  const line = linesOf(source)[lineNumber - 1];
  if (!line) throw new Error("整形ツールが不正な修正位置を返しました。");
  const start = line.start + column - 1;
  const count = fix.deleteCount || 0;
  if (column < 1 || column > line.content.length + 1 || count < -1 ||
      (count !== -1 && column - 1 + count > line.content.length)) {
    throw new Error("整形ツールが不正な修正範囲を返しました。");
  }
  if (count === -1) {
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
  return results.filter((result) => result.fixInfo && path.resolve(cwd, result.fileName) === filename);
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
    if (fix.ruleNames[0] === "MD004" && list !== undefined && fix.fixInfo.deleteCount === 1 &&
        /^[*+-]$/u.test(fix.fixInfo.insertText || "")) {
      if (!markerGroups.has(list)) {
        const group = [];
        markerGroups.set(list, group);
        groups.push(group);
      }
      markerGroups.get(list).push(fix);
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
  const dependencies = await runtime(options.runtimeDir || scriptDirectory);
  const originalSnapshot = semanticSnapshot(source, dependencies.parseMarkdown);
  const visited = new Set([source]);
  let current = source;
  let attempted = 0;
  for (let pass = 0; pass < MAX_PASSES; pass++) {
    const projected = projection(current, dependencies.parseMarkdown);
    let fixes = await lint(current, dependencies, settings);
    if (projected.source !== current) {
      // リストの表記は正しい階層を持つ引用版を基準とし、元の解析との往復を防ぐ。
      fixes = fixes.filter((fix) => fix.ruleNames[0] !== "MD004");
      fixes.push(...(await lint(projected.source, dependencies, settings))
        .filter((fix) => !projected.syntheticBlankRows.has(fixPosition(fix)[0])));
    }
    // 範囲で先に絞ると、通常のリストでも一部のマーカーだけが変わって分裂する。
    const groups = fixGroups(fixes, projected.itemLists)
      .filter((group) => group.every((fix) => inRange(current, fix, selection)));
    let changed = false;
    const appliedRanges = [];
    for (const group of groups) {
      attempted += group.length;
      if (attempted > MAX_FIXES) throw new Error("修正が多すぎるため整形を中止しました。");
      const ranges = group.map((fix) => {
        const [line, column] = fixPosition(fix);
        return { line, column, end: column + Math.max(0, fix.fixInfo.deleteCount || 0), deleted: fix.fixInfo.deleteCount === -1 };
      });
      // 同じ解析結果に基づく重複修正は、次の解析で再評価する。
      if (ranges.some((candidate) => appliedRanges.some((range) => range.line === candidate.line &&
          (candidate.deleted || range.deleted || (candidate.end > range.column && candidate.column < range.end) ||
           candidate.column === range.column)))) continue;
      // 同じリストのマーカー変更だけはまとめて検証し、途中の混在でリストが分裂するのを避ける。
      // 全て同じ幅の１文字置換なので、下の行からまとめて変えても他の修正位置はずれない。
      const candidate = group.reduce((value, fix) => applyFix(value, fix), current);
      if (candidate === current) continue;
      if (semanticSnapshot(candidate, dependencies.parseMarkdown) === originalSnapshot) {
        // 範囲内の改行増減に追従し、次の解析で元の選択範囲外を整形しない。
        if (selection) selection.end += candidate.length - current.length;
        current = candidate;
        changed = true;
        appliedRanges.push(...ranges);
      }
    }
    if (!changed) {
      if (semanticSnapshot(current, dependencies.parseMarkdown) !== originalSnapshot) {
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
    ["--range-start-column", "rangeStartColumn"], ["--range-end-column", "rangeEndColumn"]]);
  const arguments_ = process.argv.slice(2);
  for (let index = 0; index < arguments_.length; index++) {
    const name = names.get(arguments_[index]);
    if (!name || !arguments_[index + 1] || arguments_[index + 1].startsWith("--")) {
      throw new Error("引数は --runtime-dir、--filename、--config を指定してください。");
    }
    if (options[name] !== undefined) throw new Error("同じ引数を複数回指定できません。");
    options[name] = arguments_[++index];
  }
  if (!options.runtimeDir) throw new Error("--runtime-dir を指定してください。");
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

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  cli().catch((error) => {
    const detail = error?.message?.split(/[\r\n]/u)[0] || "不明なエラー";
    process.stderr.write(`GitLab Markdown の整形に失敗しました: ${detail}\n`);
    process.exitCode = 1;
  });
}
