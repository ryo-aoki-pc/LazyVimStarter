import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import test from "node:test";
import { formatMarkdown } from "../format.mjs";

const packageDir = fileURLToPath(new URL("../", import.meta.url));
const runtimeDir = process.env.GLFM_FORMAT_RUNTIME_DIR || packageDir;
const runtimeRequire = createRequire(path.join(runtimeDir, "package.json"));
const { lint } = await import(pathToFileURL(runtimeRequire.resolve("markdownlint/promise")));

test("project custom fixes cannot change include targets while safe prose fixes continue", async (t) => {
  const cwd = await mkdtemp(path.join(tmpdir(), "glfm-custom-rule-test-"));
  t.after(() => rm(cwd, { recursive: true, force: true }));
  const rulePath = path.join(cwd, "include-rule.cjs");
  // 通常ルールが触らない include 内部への修正を、プロジェクトのカスタムルールで発生させる。
  await writeFile(rulePath, `module.exports = {
    names: ["test-include-filename"],
    description: "Replace a file name",
    tags: ["test"],
    parser: "none",
    function(params, onError) {
      params.lines.forEach((line, index) => {
        if (!line.includes("example.md")) return;
        const column = line.indexOf("example.md") + 1;
        onError({
          lineNumber: index + 1,
          range: [column, "example.md".length],
          fixInfo: { editColumn: column, deleteCount: "example.md".length, insertText: "replacement.md" }
        });
      });
    }
  };\n`);
  const config = { default: false, MD009: true, "test-include-filename": true };
  await writeFile(path.join(cwd, ".markdownlint-cli2.jsonc"), JSON.stringify({
    config, customRules: ["./include-rule.cjs"],
  }));
  // 説明リストの外に置き、その構造保護だけで誤って試験が通ることを避ける。
  const input = "Outside example.md \n\n::include{file=example.md}\n\nTerm\n: Description \n";
  const results = await lint({ strings: { fixture: input }, config, customRules: [runtimeRequire(rulePath)] });
  const customFixes = results.fixture.filter((result) => result.ruleNames.includes("test-include-filename"));
  assert.equal(customFixes.length, 2);
  const includeFixes = customFixes.filter((result) => result.lineNumber === 3);
  assert.equal(includeFixes.length, 1, "the fixture actually requests a change to the include target");
  const { lineNumber, fixInfo } = includeFixes[0];
  assert.equal(lineNumber, 3);
  assert.equal(input.split("\n")[lineNumber - 1].slice(fixInfo.editColumn - 1, fixInfo.editColumn - 1 + fixInfo.deleteCount), "example.md");
  assert.equal(fixInfo.insertText, "replacement.md");
  assert.ok(results.fixture.some((result) => result.ruleNames.includes("MD009")));

  const options = { filename: path.join(cwd, "example.md"), cwd, runtimeDir };
  const output = await formatMarkdown(input, options);
  // 同じルールの本文側の修正が適用され、カスタムルール自体が無視されていないことも確かめる。
  assert.equal(output, "Outside replacement.md\n\n::include{file=example.md}\n\nTerm\n: Description\n");
  assert.equal(await formatMarkdown(output, options), output);
});
