import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { copyFile, mkdtemp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import test from "node:test";
import { formatMarkdown } from "../format.mjs";

const packageDir = fileURLToPath(new URL("../", import.meta.url));
const formatterPath = path.join(packageDir, "format.mjs");
const runtimeDir = process.env.GLFM_FORMAT_RUNTIME_DIR || packageDir;
const runtimeRequire = createRequire(path.join(runtimeDir, "package.json"));
const { markdownToHTML, parseMarkdown } = runtimeRequire("comrak");
const { lint: lintMarkdown } = await import(pathToFileURL(runtimeRequire.resolve("markdownlint/promise")));
const parserOptions = {
  extension: {
    descriptionLists: true,
    table: true,
    autolink: true,
    tasklist: true,
    strikethrough: true,
    footnotes: true,
    mathDollars: true,
    mathCode: true,
    multilineBlockQuotes: true,
    alerts: true,
  },
  parse: { relaxedTasklistMatching: true, leaveFootnoteDefinitions: true },
  render: { unsafe: true },
};

async function inProject(t, rules, callback) {
  const cwd = await mkdtemp(path.join(tmpdir(), "glfm-format-test-"));
  t.after(() => rm(cwd, { recursive: true, force: true }));
  await writeFile(path.join(cwd, ".markdownlint.json"), JSON.stringify({ default: false, ...rules }));
  const options = { filename: path.join(cwd, "example.md"), cwd, runtimeDir };
  return callback(options);
}

function rendered(text) {
  return markdownToHTML(text, parserOptions);
}

function definitionHTML(text) {
  const html = rendered(text);
  const sections = [];
  const tags = /<\/?dl>/g;
  let depth = 0;
  let start = 0;
  for (const match of html.matchAll(tags)) {
    if (match[0] === "<dl>") {
      if (depth++ === 0) start = match.index;
    } else if (--depth === 0) {
      sections.push(html.slice(start, match.index + match[0].length));
    }
  }
  assert.equal(depth, 0, "Comrak rendered balanced definition lists");
  assert.ok(sections.length > 0, "fixture actually renders as a GLFM definition list");
  return sections;
}

function descriptionNodeCount(text, kind) {
  return parseMarkdown(text, parserOptions).nodes.filter((node) => {
    const value = node.data.value;
    return (typeof value === "string" ? value : Object.keys(value)[0]) === kind;
  }).length;
}

test("safe fixes inside and outside descriptions coexist with rejected MD007 fixes", async (t) => {
  await inProject(t, { MD007: true, MD009: true, MD018: true }, async (options) => {
    const input = "#Title \n\n用語\n: 説明 \n\n  - 子の項目 \n    - 孫の項目 \n\n##After\n";
    const output = await formatMarkdown(input, options);
    assert.equal(output, "# Title\n\n用語\n: 説明\n\n  - 子の項目\n    - 孫の項目\n\n## After\n");
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(await formatMarkdown(output, options), output);
  });
});

test("MD014 does not remove a dollar from ordinary description text mistaken for code", async (t) => {
  await inProject(t, { MD009: true, MD014: true }, async (options) => {
    const input = "Term\n: First paragraph \n\n    $ literal description text\n\n  Another paragraph \n";
    assert.ok(!rendered(input).includes("<pre>"), "four source spaces are still a paragraph inside the description");
    const output = await formatMarkdown(input, options);
    assert.equal(output, "Term\n: First paragraph\n\n    $ literal description text\n\n  Another paragraph\n");
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
  });
});

test("genuine code inside descriptions keeps its literal content while enabled prose fixes still run", async (t) => {
  await inProject(t, { MD004: false, MD007: true, MD009: true, MD014: true }, async (options) => {
    const input = [
      "Term", ": Description ", "", "  ```sh", "  $ echo fenced", "  $ pwd", "  ```", "",
      "      $ echo indented", "      $ pwd", "", "  * child ", "",
    ].join("\n");
    assert.equal(descriptionNodeCount(input, "CodeBlock"), 2, "fixture contains both fenced and indented code inside the description");
    const output = await formatMarkdown(input, options);
    assert.equal(output, input.replace(": Description \n", ": Description\n").replace("  * child \n", "  * child\n"));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
  });
});

test("project marker style formats actual nested lists inside descriptions", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD007: true, MD009: true }, async (options) => {
    const input = "Term\n: Description \n\n  * child \n    * grandchild \n";
    const output = await formatMarkdown(input, options);
    assert.equal(output, "Term\n: Description\n\n  - child\n    - grandchild\n");
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
  });
});

test("the sublist marker style follows real list nesting inside descriptions and converges", async (t) => {
  await inProject(t, { MD004: { style: "sublist" }, MD007: false, MD009: true }, async (options) => {
    const input = "- Outside \n\nTerm\n: Description \n\n  - child \n    - grandchild \n    - sibling \n";
    const markers = (text) => Object.fromEntries([...text.matchAll(/^(?:>[ \t]*)*[ \t]*([*+-]) (Outside|child|grandchild|sibling)$/gm)]
      .map((match) => [match[2], match[1]]));
    const output = await formatMarkdown(input, options);
    const styles = markers(output);
    assert.equal(styles.Outside, "-");
    assert.equal(styles.child, styles.Outside, "the description itself does not add an unordered-list nesting level");
    assert.notEqual(styles.grandchild, styles.child, "a sublist marker differs from its real parent list marker");
    assert.equal(styles.sibling, styles.grandchild, "siblings at the same nesting depth use a consistent marker");
    assert.ok(!output.split("\n").some((line) => line.endsWith(" ")));
    assert.equal(rendered(output), rendered(input));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(await formatMarkdown(output, options), output);

    const selectedSublist = await formatMarkdown(input, { ...options, range: { start: [7, 0], end: [8, Infinity] } });
    assert.equal(selectedSublist.split("\n").slice(0, 6).join("\n"), input.split("\n").slice(0, 6).join("\n"));
    const selectedStyles = markers(selectedSublist);
    assert.notEqual(selectedStyles.grandchild, "-");
    assert.equal(selectedStyles.grandchild, selectedStyles.sibling);
    assert.deepEqual(definitionHTML(selectedSublist), definitionHTML(input));
    const selectedFirst = await formatMarkdown(input, { ...options, range: { start: [7, 0], end: [7, Infinity] } });
    assert.equal(selectedFirst, input.replace("    - grandchild \n", "    - grandchild\n"));

    const variants = [
      {
        name: "four-space child list that ordinary Markdown misreads as code",
        input: "- Outside \n\nTerm\n: Description \n\n    - child \n      - grandchild \n      - sibling \n",
      },
      {
        name: "nested descriptions inside an outer blockquote",
        input: "- Outside \n\n> Term\n> : Description \n>\n>   Nested term\n>   : Nested description \n>\n>     - child \n>       - grandchild \n>       - sibling \n",
        definitions: 2,
      },
      {
        name: "tilde description marker",
        input: "- Outside \n\nTerm\n~ Description \n\n  - child \n    - grandchild \n    - sibling \n",
      },
      {
        name: "loose grandchild siblings separated by an empty line",
        input: "- Outside \n\nTerm\n: Description \n\n  - child \n    - grandchild \n\n    - sibling \n",
      },
    ];
    for (const variant of variants) {
      assert.equal(descriptionNodeCount(variant.input, "DescriptionList"), variant.definitions || 1, variant.name);
      const formatted = await formatMarkdown(variant.input, options);
      const variantStyles = markers(formatted);
      assert.equal(variantStyles.Outside, "-", variant.name);
      assert.equal(variantStyles.child, variantStyles.Outside, variant.name);
      assert.notEqual(variantStyles.grandchild, variantStyles.child, variant.name);
      assert.equal(variantStyles.sibling, variantStyles.grandchild, variant.name);
      assert.ok(!formatted.split("\n").some((line) => line.endsWith(" ")), variant.name);
      assert.equal(rendered(formatted), rendered(variant.input), variant.name);
      assert.deepEqual(definitionHTML(formatted), definitionHTML(variant.input), variant.name);
      assert.equal(await formatMarkdown(formatted, options), formatted, variant.name);
      assert.equal(
        formatted.replace(/([*+-]) (grandchild|sibling)$/gm, "- $2"),
        variant.input.replace(/ +$/gm, ""),
        `${variant.name}: only trailing whitespace and real sublist markers change`,
      );
    }
  });
});

test("range formatting fixes selected whitespace while requiring the whole list for a marker-style change", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD007: true, MD009: true }, async (options) => {
    const input = "Term\n: Description \n\n  * [~] First task \n  * [x] Second task \n";
    const selectedFirst = await formatMarkdown(input, { ...options, range: { start: [4, 0], end: [4, 99] } });
    assert.equal(selectedFirst, "Term\n: Description \n\n  * [~] First task\n  * [x] Second task \n");
    assert.deepEqual(definitionHTML(selectedFirst), definitionHTML(input));
    const selectedList = await formatMarkdown(input, { ...options, range: { start: [4, 0], end: [5, 99] } });
    assert.equal(selectedList, "Term\n: Description \n\n  - [~] First task\n  - [x] Second task\n");
    assert.deepEqual(definitionHTML(selectedList), definitionHTML(input));
    const child = spawnSync(process.execPath, [formatterPath, "--runtime-dir", runtimeDir, "--filename", options.filename, "--range-start", "4", "--range-end", "4"], {
      cwd: options.cwd, input, encoding: "utf8", timeout: 15000,
    });
    assert.equal(child.status, 0, child.stderr);
    assert.equal(child.stdout, selectedFirst);
    assert.equal(child.stderr, "");
  });
});

test("partial range formatting also keeps ordinary Markdown list marker changes atomic", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD009: true }, async (options) => {
    const input = "* First item \n* Second item \n";
    const partial = await formatMarkdown(input, { ...options, range: { start: [1, 0], end: [1, Infinity] } });
    assert.equal(partial, "* First item\n* Second item \n");
    assert.equal(rendered(partial), rendered(input));
    const complete = await formatMarkdown(input, { ...options, range: { start: [1, 0], end: [2, Infinity] } });
    assert.equal(complete, "- First item\n- Second item\n");
    assert.equal(rendered(complete), rendered(input));
  });
});

test("range columns use Neovim UTF-8 byte offsets around Japanese text and emoji", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD009: true }, async (options) => {
    const input = "Term \n: 日本語🌸 \n\n  * child \n";
    const trailingColumn = Buffer.byteLength(": 日本語🌸");
    const output = await formatMarkdown(input, { ...options, range: { start: [2, trailingColumn], end: [2, trailingColumn + 1] } });
    assert.equal(output, "Term \n: 日本語🌸\n\n  * child \n");
    assert.equal(await formatMarkdown(input, { ...options, range: { start: [2, 2], end: [2, 5] } }), input);
    const child = spawnSync(process.execPath, [formatterPath, "--runtime-dir", runtimeDir, "--filename", options.filename,
      "--range-start", "2", "--range-end", "2", "--range-start-column", String(trailingColumn), "--range-end-column", String(trailingColumn + 1)], {
      cwd: options.cwd, input, encoding: "utf8", timeout: 15000,
    });
    assert.equal(child.status, 0, child.stderr);
    assert.equal(child.stdout, output);
    assert.equal(child.stderr, "");
  });
});

test("ranges round Japanese and emoji byte boundaries without changing unselected CRLF text", async (t) => {
  await inProject(t, { MD009: true, MD018: true }, async (options) => {
    const input = "Outside \r\n\r\n#日本語🌸 \r\n\r\nTerm\r\n: Description \r\n";
    assert.equal(descriptionNodeCount(input, "DescriptionList"), 1);
    // 「日」と絵文字の途中のバイトから始め、終点は絵文字の先頭バイトも含めて確かめる。
    const variants = [
      {
        name: "Japanese start and emoji end leave trailing whitespace outside the range",
        range: { start: [3, 2], end: [3, Buffer.byteLength("#日本語")] },
        expected: input.replace("#日本語🌸", "# 日本語🌸"),
      },
      {
        name: "including the trailing space permits both heading and whitespace fixes",
        range: { start: [3, 2], end: [3, Buffer.byteLength("#日本語🌸")] },
        expected: input.replace("#日本語🌸 \r\n", "# 日本語🌸\r\n"),
      },
      {
        name: "an emoji start excludes the heading marker but includes trailing whitespace",
        range: { start: [3, Buffer.byteLength("#日本語") + 2], end: [3, Infinity] },
        expected: input.replace("#日本語🌸 \r\n", "#日本語🌸\r\n"),
      },
    ];
    for (const { name, range, expected } of variants) {
      const output = await formatMarkdown(input, { ...options, range });
      assert.equal(output, expected, name);
      assert.deepEqual(definitionHTML(output), definitionHTML(input), name);
      assert.equal(output.replaceAll("\r\n", "").includes("\n"), false, name);
      assert.equal(await formatMarkdown(output, { ...options, range }), output, name);
    }
  });
});

test("CRLF range anchors retain outside text across inserted and deleted lines around GLFM descriptions", async (t) => {
  await inProject(t, { MD009: true, MD012: true, MD018: true, MD022: true }, async (options) => {
    const input = "#外側前 \r\n\r\n#選択🌸 \r\n本文 \r\n\r\n\r\n\r\n用語\r\n: 説明🌸 \r\n\r\n#外側後 \r\n";
    assert.equal(descriptionNodeCount(input, "DescriptionList"), 1);
    const output = await formatMarkdown(input, { ...options, range: { start: [3, 0], end: [10, -1] } });
    assert.equal(output, "#外側前 \r\n\r\n# 選択🌸\r\n\r\n本文\r\n\r\n用語\r\n: 説明🌸\r\n\r\n#外側後 \r\n");
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(output.replaceAll("\r\n", "").includes("\n"), false);
    assert.equal(await formatMarkdown(output, { ...options, range: { start: [3, 0], end: [9, -1] } }), output);
  });
});

test("range anchors follow deleted blank lines without admitting originally outside text on a later pass", async (t) => {
  await inProject(t, { MD009: true, MD012: true, MD018: true }, async (options) => {
    const input = "#OutsideBefore \n\n#Selected \n\n\n\n#OutsideAfter \n";
    const output = await formatMarkdown(input, { ...options, range: { start: [3, 0], end: [6, -1] } });
    assert.equal(output, "#OutsideBefore \n\n# Selected\n\n\n#OutsideAfter \n");
    assert.ok(output.startsWith("#OutsideBefore \n\n"));
    assert.ok(output.endsWith("#OutsideAfter \n"), "the outside heading now occupies an earlier row but remains unchanged");
    assert.equal(await formatMarkdown(output, { ...options, range: { start: [3, 0], end: [5, -1] } }), output);
  });
});

test("range anchors follow several inserted newlines and newly exposed heading fixes across passes", async (t) => {
  await inProject(t, { MD009: true, MD018: true, MD022: true }, async (options) => {
    const input = "#OutsideBefore \n\n#First \nfirst paragraph \n#Second \nsecond paragraph \n\n#OutsideAfter \n";
    const output = await formatMarkdown(input, { ...options, range: { start: [3, 0], end: [7, -1] } });
    assert.equal(output, "#OutsideBefore \n\n# First\n\nfirst paragraph\n\n# Second\n\nsecond paragraph\n\n#OutsideAfter \n");
    assert.ok(output.startsWith("#OutsideBefore \n\n"));
    assert.ok(output.endsWith("#OutsideAfter \n"));
    assert.equal(await formatMarkdown(output, { ...options, range: { start: [3, 0], end: [10, -1] } }), output);
  });
});

test("a linewise range ending on an empty line accepts column minus one and preserves its unselected newline", async (t) => {
  await inProject(t, { MD009: true, MD012: true }, async (options) => {
    const input = "Outside before \n\nSelected paragraph \n\n\nOutside after \n";
    const output = await formatMarkdown(input, { ...options, range: { start: [3, 0], end: [5, -1] } });
    assert.equal(output, "Outside before \n\nSelected paragraph\n\n\nOutside after \n");
    const child = spawnSync(process.execPath, [formatterPath, "--runtime-dir", runtimeDir, "--filename", options.filename,
      "--range-start", "3", "--range-end", "5", "--range-start-column", "0", "--range-end-column", "-1"], {
      cwd: options.cwd, input, encoding: "utf8", timeout: 15000,
    });
    assert.equal(child.status, 0, child.stderr);
    assert.equal(child.stdout, output);
    assert.equal(child.stderr, "");
  });
});

test("multiline terms, multiple descriptions, and nested descriptions retain their relationships", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD007: true, MD009: true, MD012: true }, async (options) => {
    const input = [
      "First term line", "second term line", ": First description ", ": Second description ", "",
      "  Nested term", "  : Nested description ", "", "    * nested child ", "",
      "Last term", ": Last description ", "",
    ].join("\n");
    assert.equal(descriptionNodeCount(input, "DescriptionList"), 2);
    const output = await formatMarkdown(input, options);
    assert.ok(output.startsWith("First term line\nsecond term line\n:"));
    assert.ok(output.includes("    - nested child\n"));
    assert.ok(!output.split("\n").some((line) => line.endsWith(" ")));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(await formatMarkdown(output, options), output);
  });
});

test("quote container and tab indentation survive safe description repairs", async (t) => {
  await inProject(t, { MD007: true, MD009: true, MD010: true }, async (options) => {
    for (const input of [
      "> Term\n> : Description \n>\n>   - child \n>     - grandchild \n",
      "Term\n: Description \n\n\t$ ordinary paragraph\n\n  - child \n",
    ]) {
      const output = await formatMarkdown(input, options);
      assert.deepEqual(definitionHTML(output), definitionHTML(input));
      assert.ok(!output.includes("Description \n"));
      assert.equal(await formatMarkdown(output, options), output);
    }
  });
});

test("descriptions keep their multiline quote and numbered-list containers while safe fixes converge", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD007: true, MD009: true }, async (options) => {
    const variants = [
      {
        name: "GitLab multiline quote",
        input: ">>>\nTerm\n: Description \n\n  * child \n>>>\n\nOutside \n",
        expected: ">>>\nTerm\n: Description\n\n  - child\n>>>\n\nOutside\n",
        container: "MultilineBlockQuote",
      },
      {
        name: "numbered list starting at three",
        input: "3. Term\n   : Description \n\n     * child \n       * grandchild \n\n4. After \n",
        expected: "3. Term\n   : Description\n\n     - child\n       - grandchild\n\n4. After\n",
        container: "List",
      },
    ];
    for (const { name, input, expected, container } of variants) {
      const nodes = parseMarkdown(input, parserOptions).nodes;
      const description = nodes.find((node) => {
        const value = node.data.value;
        return (typeof value === "string" ? value : Object.keys(value)[0]) === "DescriptionList";
      });
      assert.ok(description, `${name}: fixture contains a real description list`);
      // 引用や番号付きリストの所属を、描画前の公式パーサーでも確認する。
      const ancestors = [];
      for (let parent = description.parent; parent !== undefined; parent = nodes[parent].parent) {
        const value = nodes[parent].data.value;
        ancestors.push(typeof value === "string" ? value : Object.keys(value)[0]);
      }
      assert.ok(ancestors.includes(container), `${name}: description belongs to its intended container`);
      if (container === "List") {
        const list = nodes.find((node) => node.data.value?.List?.list_type === "Ordered");
        assert.equal(list?.data.value.List.start, 3, "the numbered list really starts at three");
      }
      const output = await formatMarkdown(input, options);
      assert.equal(output, expected, name);
      assert.equal(rendered(output), rendered(input), name);
      assert.deepEqual(definitionHTML(output), definitionHTML(input), name);
      assert.equal(await formatMarkdown(output, options), output, name);
    }
  });
});

test("fenced examples and unmatched fences are not mistaken for descriptions", async (t) => {
  await inProject(t, { MD007: true, MD009: true, MD018: true }, async (options) => {
    const input = [
      "```markdown", "Fake term", ": fake description", "  - fake child", "#literal", "```", "",
      "#Heading", "", "Term", ": Actual description ", "", "  - actual child ", "",
      "~~~text", "Other fake term", ": unfinished fence description", "    $ literal code", "#literal", "",
    ].join("\n");
    assert.equal(descriptionNodeCount(input, "DescriptionList"), 1);
    const output = await formatMarkdown(input, options);
    assert.ok(output.includes("# Heading\n"));
    assert.ok(output.includes(": Actual description\n\n  - actual child\n"));
    assert.equal(output.slice(0, output.indexOf("# Heading")), input.slice(0, input.indexOf("#Heading")));
    assert.equal(output.slice(output.indexOf("~~~text")), input.slice(input.indexOf("~~~text")));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
  });
});

test("YAML, TOML, and JSON front matter stay opaque while the following heading is repaired", async (t) => {
  await inProject(t, { MD009: true, MD018: true }, async (options) => {
    for (const [delimiter, body] of [
      ["---", "title: example \n#not-a-heading\nterm:\n  - value"],
      ["+++", "title = 'example' \n#not-a-heading\nterm = ': description'"],
      [";;;", '{\n  "term": ": description", \n  "heading": "#literal"\n}'],
    ]) {
      const frontmatter = `${delimiter}\n${body}\n${delimiter}\n`;
      const output = await formatMarkdown(`${frontmatter}\n#Outside\n\nTerm\n: Description \n`, options);
      assert.ok(output.startsWith(frontmatter), `${delimiter} front matter bytes are preserved`);
      assert.ok(output.includes("# Outside\n"));
      assert.ok(output.endsWith(": Description\n"));
    }
  });
});

test("GLFM math, inline diffs, TOC, inapplicable tasks, includes, and footnotes survive formatting", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD007: true, MD009: true, MD014: true }, async (options) => {
    const input = [
      "[[_TOC_]]", "", "Term", ": $`x + y`$ and $z$ and {+added+} and {-removed-} [^note] ", "",
      "  * [~] Inapplicable task ", "  * [x] Done ", "", "  ::include{file=example.md}", "",
      "  ```math", "  x + y = z", "  ```", "", "[^note]: Footnote", "    continuation", "",
    ].join("\n");
    const output = await formatMarkdown(input, options);
    assert.ok(output.startsWith("[[_TOC_]]\n"));
    assert.ok(output.includes("$`x + y`$ and $z$ and {+added+} and {-removed-} [^note]\n"));
    assert.ok(output.includes("  - [~] Inapplicable task\n  - [x] Done\n"));
    assert.ok(output.includes("  ::include{file=example.md}\n"));
    assert.ok(output.includes("  ```math\n  x + y = z\n  ```\n"));
    assert.ok(output.endsWith("[^note]: Footnote\n    continuation\n"));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
  });
});

test("GLFM math and both inline diff forms keep their contents while prose is fixed and includes stay intact", async (t) => {
  const rules = { MD009: true, MD049: { style: "asterisk" }, MD050: { style: "asterisk" } };
  await inProject(t, rules, async (options) => {
    const displayMath = "$$\n_variable_ \n$$\n";
    // 説明リストの構造保護で試験が通らないよう、表示数式を説明の外に置く。
    const input = displayMath + "\nOutside _emphasis_ and __strong__ \n\nTerm\n: $_variable_$ and $`_code_`$ and [+_added_+] and [-__removed__-] and {+_added_+} and {-__removed__-} \n\n  ::include{file=_example_.md}\n";
    assert.equal(descriptionNodeCount(input, "DescriptionList"), 1);
    assert.equal(descriptionNodeCount(input, "Math"), 3, "display, dollar, and code math are recognized by Comrak");
    const nodes = parseMarkdown(input, parserOptions).nodes;
    const math = nodes.find((node) => node.data.value?.Math?.display_math);
    assert.equal(math?.data.value.Math.literal, "\n_variable_ \n", "display math actually contains the trailing space");
    for (let parent = math.parent; parent !== undefined; parent = nodes[parent].parent) {
      assert.notEqual(nodes[parent].data.value, "DescriptionList", "display math is outside the description list");
    }
    // 独立した lint で、保護対象の数式内部に実際の修正候補があることを確認する。
    const results = await lintMarkdown({ strings: { fixture: input }, config: { default: false, ...rules } });
    const mathFix = results.fixture.find((result) => result.lineNumber === 2 && result.ruleNames.includes("MD009"));
    assert.ok(mathFix?.fixInfo, "MD009 requests a fix inside display math");
    assert.equal(mathFix.fixInfo.editColumn, "_variable_".length + 1);
    assert.equal(mathFix.fixInfo.deleteCount, 1);
    assert.equal(mathFix.fixInfo.insertText || "", "");
    const output = await formatMarkdown(input, options);
    const expected = input.replace("Outside _emphasis_ and __strong__ \n", "Outside *emphasis* and **strong**\n").replace("{-__removed__-} \n", "{-__removed__-}\n");
    assert.equal(output, expected);
    assert.ok(output.startsWith(displayMath + "\n"), "display math source bytes remain intact despite the MD009 candidate");
    assert.equal(rendered(output), rendered(input));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(await formatMarkdown(output, options), output);
  });
});

test("an alert inside a description keeps its type, body, and placement while its content is formatted", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD007: true, MD009: true }, async (options) => {
    const input = "Term\n: Description \n\n  > [!NOTE]\n  > Alert body \n  >\n  > * nested item \n";
    assert.equal(descriptionNodeCount(input, "Alert"), 1, "the official parser recognizes an alert inside the description");
    assert.ok(rendered(input).includes("markdown-alert-note"));
    const output = await formatMarkdown(input, options);
    assert.equal(output, "Term\n: Description\n\n  > [!NOTE]\n  > Alert body\n  >\n  > - nested item\n");
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(descriptionNodeCount(output, "Alert"), 1);
    assert.equal(await formatMarkdown(output, options), output);
  });
});

test("global base configuration, project overrides, and inline disable directives are respected", async (t) => {
  await inProject(t, { MD004: { style: "asterisk" }, MD009: true }, async (options) => {
    const baseConfig = path.join(options.cwd, "base.markdownlint-cli2.jsonc");
    await writeFile(baseConfig, JSON.stringify({ config: { default: false, MD004: { style: "dash" }, MD009: true } }));
    const input = "Term\n: Description \n\n  - child \n\n<!-- markdownlint-disable MD009 -->\nKeep this space \n<!-- markdownlint-enable MD009 -->\nRemove this space \n";
    const output = await formatMarkdown(input, { ...options, config: baseConfig });
    assert.ok(output.includes(": Description\n\n  * child\n"), "project style overrides global dash style");
    assert.ok(output.includes("Keep this space \n"), "inline disable still applies");
    assert.ok(output.includes("Remove this space\n"));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    await rm(path.join(options.cwd, ".markdownlint.json"));
    assert.equal(
      await formatMarkdown("Term\n: Description \n\n  * child \n", { ...options, config: baseConfig }),
      "Term\n: Description\n\n  - child\n",
      "the explicit base configuration applies when the project supplies no replacement",
    );
  });
});

test("named unsaved buffers and virtual unnamed buffers use configuration without writing markdown files", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD009: true }, async (options) => {
    await mkdir(path.join(options.cwd, "nested"));
    await writeFile(path.join(options.cwd, "nested", ".markdownlint.json"), JSON.stringify({ default: false, MD004: { style: "asterisk" }, MD009: true }));
    const filename = path.join(options.cwd, "nested", "not-saved.md");
    const output = await formatMarkdown("Term\n: Description \n\n  - child \n", { ...options, filename, cwd: path.dirname(filename) });
    assert.equal(output, "Term\n: Description\n\n  * child\n");
    assert.equal(existsSync(filename), false);
    const virtualFilename = path.join(options.cwd, "__glfm_unnamed.md");
    const virtual = await formatMarkdown("Term\n: Description \n\n  * child \n", { ...options, filename: virtualFilename });
    assert.equal(virtual, "Term\n: Description\n\n  - child\n");
    assert.equal(existsSync(virtualFilename), false);
  });
});

test("project globs and fix settings cannot cause on-disk edits, and ignored buffers stay unchanged", async (t) => {
  await inProject(t, {}, async (options) => {
    await rm(path.join(options.cwd, ".markdownlint.json"));
    const configPath = path.join(options.cwd, ".markdownlint-cli2.jsonc");
    const config = { config: { default: false, MD009: true }, fix: true, globs: ["**/*.md"] };
    await writeFile(configPath, JSON.stringify(config));
    const diskContents = "Original content on disk.\n";
    await writeFile(options.filename, diskContents);
    const input = "Term\n: Unsaved description \n";
    assert.equal(await formatMarkdown(input, options), "Term\n: Unsaved description\n");
    assert.equal(await readFile(options.filename, "utf8"), diskContents);
    await writeFile(configPath, JSON.stringify({ ...config, ignores: ["**/*.md"] }));
    assert.equal(await formatMarkdown(input, options), input);
    assert.equal(await readFile(options.filename, "utf8"), diskContents);
  });
});

test("invalid project configuration fails without producing replacement buffer text", async (t) => {
  await inProject(t, {}, async (options) => {
    await writeFile(path.join(options.cwd, ".markdownlint.json"), '{"MD004": [\n');
    await assert.rejects(formatMarkdown("Term\n: Description \n", options), /設定|config|parse/i);
    const child = spawnSync(process.execPath, [formatterPath, "--runtime-dir", runtimeDir, "--filename", options.filename], {
      cwd: options.cwd, input: "Term\n: Description \n", encoding: "utf8", timeout: 15000,
    });
    assert.notEqual(child.status, 0);
    assert.equal(child.stdout, "");
    assert.match(child.stderr, /設定|config|parse/i);
  });
});

test("Japanese text and CRLF line endings remain intact and formatting is idempotent", async (t) => {
  await inProject(t, { MD007: true, MD009: true }, async (options) => {
    const input = "日本語の用語\r\n: 日本語の説明 \r\n\r\n  - 日本語の子項目 \r\n";
    const output = await formatMarkdown(input, options);
    assert.equal(output, "日本語の用語\r\n: 日本語の説明\r\n\r\n  - 日本語の子項目\r\n");
    assert.equal(output.replaceAll("\r\n", "").includes("\n"), false);
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(await formatMarkdown(output, options), output);
  });
});

test("CLI emits only formatted stdin on stdout and honors the unsaved filename context", async (t) => {
  await inProject(t, { MD007: true, MD009: true }, async (options) => {
    const input = "Term\n: Description \n\n  - child \n";
    const child = spawnSync(process.execPath, [formatterPath, "--runtime-dir", runtimeDir, "--filename", options.filename], {
      cwd: options.cwd, input, encoding: "utf8", timeout: 15000,
    });
    assert.equal(child.status, 0, child.stderr);
    assert.equal(child.stdout, "Term\n: Description\n\n  - child\n");
    assert.equal(child.stderr, "");
    assert.equal(existsSync(options.filename), false);
  });
});

test("CLI fails clearly with no stdout when its dependency runtime is missing", async (t) => {
  await inProject(t, {}, async (options) => {
    const missingRuntime = path.join(options.cwd, "missing-runtime");
    const child = spawnSync(process.execPath, [formatterPath, "--runtime-dir", missingRuntime, "--filename", options.filename], {
      cwd: options.cwd, input: "Term\n: Description\n", encoding: "utf8", timeout: 15000,
    });
    assert.notEqual(child.status, 0);
    assert.equal(child.stdout, "");
    assert.match(child.stderr, /runtime|dependenc|module|install|Cannot find/i);
  });
});

test("CLI reads parent project configuration below the process working directory like markdownlint-cli2 --fix", async (t) => {
  await inProject(t, { MD004: { style: "dash" }, MD009: true }, async (options) => {
    const nested = path.join(options.cwd, "docs");
    await mkdir(nested);
    const filename = path.join(nested, "unsaved.md");
    const input = "* one \n* two\n";
    const run = (cwd) => spawnSync(process.execPath, [formatterPath, "--runtime-dir", runtimeDir, "--filename", filename], {
      cwd, input, encoding: "utf8", timeout: 15000,
    });
    const fromRoot = run(options.cwd);
    assert.equal(fromRoot.status, 0, fromRoot.stderr);
    assert.equal(fromRoot.stdout, "- one\n- two\n", "the project configuration above the file applies");
    const fromNested = run(nested);
    assert.equal(fromNested.status, 0, fromNested.stderr);
    assert.equal(fromNested.stdout, "* one\n* two\n", "a working directory below the project root does not see its configuration");
    assert.equal(existsSync(filename), false);
  });
});

test("extra blank lines at the end of the file are removed like markdownlint-cli2 --fix", async (t) => {
  await inProject(t, { MD012: true }, async (options) => {
    assert.equal(await formatMarkdown("# Title\n\ntext\n\n", options), "# Title\n\ntext\n");
    assert.equal(await formatMarkdown("# Title\n\ntext\n\n\n", options), "# Title\n\ntext\n");
    assert.equal(await formatMarkdown("Term\n: Description\n\n", options), "Term\n: Description\n");
    assert.equal(await formatMarkdown("# Title\r\n\r\ntext\r\n\r\n", options), "# Title\r\n\r\ntext\r\n");
  });
});

test("many safe fixes are applied together while rejected description fixes are isolated", async (t) => {
  await inProject(t, { MD007: true, MD009: true }, async (options) => {
    const block = (index) => `Term ${index}\n: Description ${index} \n\n  - child ${index} \n    - grandchild ${index} \n`;
    const input = Array.from({ length: 60 }, (_, index) => block(index)).join("\n");
    const output = await formatMarkdown(input, options);
    assert.equal(output, input.replace(/ +$/gm, ""));
    assert.deepEqual(definitionHTML(output), definitionHTML(input));
    assert.equal(await formatMarkdown(output, options), output);
  });
});

test("blank lines added next to description content keep the real container prefix, not the projected quote", async (t) => {
  await inProject(t, { MD032: true, MD058: true }, async (options) => {
    for (const [input, expected] of [
      ["Term\n: Description\n\n    - child\n<div>after</div>\n", "Term\n: Description\n\n    - child\n\n<div>after</div>\n"],
      ["Term\n: Description\n\n    - child\n***\n", "Term\n: Description\n\n    - child\n\n***\n"],
      ["Term\n: Description\n\n    | a | b |\n    | - | - |\n    | 1 | 2 |\nafter\n",
        "Term\n: Description\n\n    | a | b |\n    | - | - |\n    | 1 | 2 |\n\nafter\n"],
      ["> Term\n> : Description\n>\n>     - child\n> <div>after</div>\n", "> Term\n> : Description\n>\n>     - child\n>\n> <div>after</div>\n"],
    ]) {
      const output = await formatMarkdown(input, options);
      assert.equal(output, expected);
      assert.equal(rendered(output), rendered(input), "no empty blockquote appears");
    }
  });
});

test("heading and fence blank-line fixes retain real quote prefixes around description content", async (t) => {
  await inProject(t, { MD009: true, MD022: true, MD031: true }, async (options) => {
    for (const quoted of [false, true]) {
      for (const fenced of [false, true]) {
        const name = `${quoted ? "quoted" : "plain"} ${fenced ? "fence" : "heading"}`;
        const prefix = quoted ? "> " : "";
        const blank = quoted ? ">" : "";
        const block = fenced ? ["    ```text", "    literal ", "    ```"] : ["    # Inner heading"];
        const body = ["Term", ": Description ", "", ...block, "    continuation "];
        const quotedBody = (lines) => lines.map((line) => line ? prefix + line : blank).join("\n") + "\n";
        const input = "Outside \n\n" + quotedBody(body);
        assert.equal(descriptionNodeCount(input, "DescriptionList"), 1, name);
        assert.equal(descriptionNodeCount(input, fenced ? "CodeBlock" : "Heading"), 1, name);
        const expectedBody = ["Term", ": Description", "", ...block, "", "    continuation"];
        const output = await formatMarkdown(input, options);
        assert.equal(output, "Outside\n\n" + quotedBody(expectedBody), name);
        assert.equal(rendered(output), rendered(input), `${name}: inserted blanks do not create extra blockquotes`);
        assert.deepEqual(definitionHTML(output), definitionHTML(input), name);
        assert.equal(await formatMarkdown(output, options), output, name);
      }
    }
  });
});

test("the projected quote marker does not make MD027 re-indent description content", async (t) => {
  await inProject(t, { MD027: true }, async (options) => {
    const input = "Term\n:  Description\n   more\n\n    | a | b |\n    | - | - |\n\n>  Real quote\n";
    assert.equal(await formatMarkdown(input, options), input.replace(">  Real quote", "> Real quote"));
  });
});

test("lowercase table of contents markers stay intact because GitLab renders them too", async (t) => {
  await inProject(t, { MD049: true }, async (options) => {
    assert.equal(await formatMarkdown("*a*\n\n[[_toc_]]\n\n[toc]\n\n_b_\n", options), "*a*\n\n[[_toc_]]\n\n[toc]\n\n*b*\n");
  });
});

test("tabs and trailing spaces inside code stay while nearby prose is fixed", async (t) => {
  await inProject(t, { MD009: true, MD010: true }, async (options) => {
    const input = "Term\n: Description \n\n```make\nall:\n\techo done \n```\n\ntext \n";
    assert.equal(await formatMarkdown(input, options), "Term\n: Description\n\n```make\nall:\n\techo done \n```\n\ntext\n");
  });
});

test("CLI formats when its path goes through a symbolic link or junction", async (t) => {
  await inProject(t, { MD018: true }, async (options) => {
    const real = path.join(options.cwd, "real");
    const link = path.join(options.cwd, "link");
    await mkdir(real);
    await copyFile(formatterPath, path.join(real, "format.mjs"));
    await symlink(real, link, "junction");
    const child = spawnSync(process.execPath, [path.join(link, "format.mjs"), "--runtime-dir", runtimeDir, "--filename", options.filename], {
      cwd: options.cwd, input: "#Title\n", encoding: "utf8", timeout: 15000,
    });
    assert.equal(child.status, 0, child.stderr);
    assert.equal(child.stdout, "# Title\n");
  });
});
