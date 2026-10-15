import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { builtinRuleNames, defaultDisabledCategories, fixCategories, formatMarkdown, htmlCategory } from "../format.mjs";

// docs/reference/glfm-format.md の例を、書いてあるとおりに整形できるかを確かめる (文書と動作をずらさない)。
const packageDir = fileURLToPath(new URL("../", import.meta.url));
const runtimeDir = process.env.GLFM_FORMAT_RUNTIME_DIR || packageDir;
const runtimeRequire = createRequire(path.join(runtimeDir, "package.json"));
const { parseMarkdown } = runtimeRequire("comrak");
const documentPath = path.join(packageDir, "..", "..", "docs", "reference", "glfm-format.md");
const nodes = parseMarkdown(await readFile(documentPath, "utf8"), { extension: { table: true } }).nodes;

const typeOf = (node) => (typeof node.data.value === "string" ? node.data.value : Object.keys(node.data.value)[0]);
// 文書の順にノードの番号を返す。
function* walk(index = 0) {
  yield index;
  for (let child = nodes[index].first_child; child !== undefined; child = nodes[child].next_sibling) yield* walk(child);
}
function textOf(index) {
  return [...walk(index)].map((child) => nodes[child].data.value.Text ?? nodes[child].data.value.Code?.literal ?? "").join("");
}
// 見えるようにした空白とタブを戻す。
const visible = (text) => text.replaceAll("␣", " ").replaceAll("⇥", "\t");

// ### MDxxx の節ごとに、例 (整形前と整形後・変わらない) と markdownlint の設定を集める。
// ## HTML のブロック の下の ### の節は、html:<見出し> の名前で集める。
const sections = new Map();
let table;
let withoutFixes;
{
  let section;
  let pending;
  let html = false;
  for (const index of walk()) {
    const node = nodes[index];
    const type = typeOf(node);
    if (type === "Table" && table === undefined) table = index;
    if (type === "Paragraph" && textOf(index).startsWith("自動修正の無いルール:")) withoutFixes = textOf(index).match(/MD\d{3}/gu);
    if (type === "Heading" && node.data.value.Heading.level === 2) html = textOf(index) === "HTML のブロック";
    if (type === "Heading" && node.data.value.Heading.level === 3) {
      const id = textOf(index).match(/^MD\d{3}/u)?.[0] ?? (html ? `html:${textOf(index)}` : undefined);
      assert.ok(id && !sections.has(id), `見出し ${textOf(index)} はルールか HTML の節で、重ならない`);
      section = { id, config: {}, examples: [] };
      sections.set(id, section);
    }
    if (type !== "CodeBlock" || !section) continue;
    const { info, literal } = node.data.value.CodeBlock;
    const [language, kind, ...flags] = info.split(/\s+/u);
    const fixes = Object.fromEntries(flags.filter((flag) => flag.startsWith("fixes="))
      .flatMap((flag) => flag.slice("fixes=".length).split(",")).map((name) => [name, true]));
    const input = flags.includes("末尾の改行なし") ? literal.replace(/\n$/u, "") : literal;
    if (language === "json" && kind === "markdownlint") section.config = JSON.parse(literal);
    else if (kind === "整形前") pending = { input, fixes, config: section.config };
    else if (kind === "整形後") {
      assert.ok(pending, `${section.id}: 整形後 follows 整形前`);
      section.examples.push({ ...pending, expected: literal });
      pending = undefined;
    } else if (kind === "変わらない") section.examples.push({ input, expected: input, fixes, config: section.config });
    else assert.fail(`${section.id}: unknown code block "${info}"`);
  }
}

test("the reference table lists every fixable rule with its category and default", () => {
  assert.ok(table !== undefined, "the document has the rule table");
  const rows = new Map();
  for (let row = nodes[table].first_child; row !== undefined; row = nodes[row].next_sibling) {
    if (nodes[row].data.value.TableRow) continue;
    const cells = [];
    for (let cell = nodes[row].first_child; cell !== undefined; cell = nodes[cell].next_sibling) cells.push(textOf(cell).trim());
    const id = cells[0].match(/^MD\d{3}/u)[0];
    assert.equal(cells[0], `${id} ${builtinRuleNames[id][1]}`, `${id}: the table shows the rule alias`);
    rows.set(id, { category: cells[1], enabled: cells[2] });
  }
  const expected = new Map(Object.entries(fixCategories).flatMap(([category, ids]) => ids.map((id) => [id, {
    category, enabled: defaultDisabledCategories.includes(category) ? "無効" : "有効",
  }])));
  assert.deepEqual(rows, expected);
  const categorized = new Set(Object.values(fixCategories).flat());
  assert.deepEqual(withoutFixes, Object.keys(builtinRuleNames).filter((id) => !categorized.has(id)));
});

test("every fixable rule has a section with at least one example", () => {
  for (const id of Object.values(fixCategories).flat()) {
    assert.ok(sections.get(id)?.examples.length, `${id} has an example in docs/reference/glfm-format.md`);
  }
});

test("the HTML block section shows the category and examples for tables, nested HTML, and Markdown inside HTML", () => {
  const html = [...sections].filter(([id]) => id.startsWith("html:"));
  assert.deepEqual(html.map(([id]) => id),
    ["html:表", "html:入れ子の表", "html:セルの中の Markdown", "html:折りたたみ", "html:入れ物の中", "html:変えないもの"]);
  for (const [id, section] of html) assert.ok(section.examples.length, `${id} has an example`);
  assert.ok(html.flatMap(([, section]) => section.examples).some(({ input, expected }) => input !== expected),
    "HTML の節に、整形で変わる例がある");
  assert.equal(htmlCategory, "html");
});

test("every example in the reference formats exactly as documented with all markdownlint rules enabled", async (t) => {
  // 設定ファイルの無いフォルダで整形し、利用者と同じ markdownlint の既定 (全ルール有効) にする。
  const cwd = await mkdtemp(path.join(tmpdir(), "glfm-reference-test-"));
  t.after(() => rm(cwd, { recursive: true, force: true }));
  const filename = path.join(cwd, "example.md");
  for (const [id, section] of sections) {
    for (const [number, { input, expected, fixes, config }] of section.examples.entries()) {
      const options = { filename, cwd, runtimeDir, fixes, config: { default: true, ...config } };
      const name = `${id} example ${number + 1}`;
      const output = await formatMarkdown(visible(input), options);
      assert.equal(output, visible(expected), name);
      assert.equal(await formatMarkdown(output, options), output, `${name} is idempotent`);
    }
  }
});
