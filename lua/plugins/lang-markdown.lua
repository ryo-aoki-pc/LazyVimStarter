-- Markdown 言語サポート (LazyVim extra)
-- lazyvim.json は gitignore されているため、リポジトリで追跡できる import スペックで有効化する。
-- 内容: marksman LSP / markdownlint-cli2 + markdown-toc / conform (整形) /
--       nvim-lint + none-ls (lint 診断) / markdown-preview.nvim (<leader>cp) / render-markdown.nvim
return {
  { import = "lazyvim.plugins.extras.lang.markdown" },

  -- GLFM (GitLab Flavored Markdown) を壊さず整形するため、markdown の整形連鎖から
  -- prettier を除外する。prettier は数式 $...$ の \$ 化・複数行脚注の破壊・[[_TOC_]] の
  -- 再整形などで GLFM 固有構文を壊すため。代わりに GitLab 公式も採用する
  -- markdownlint-cli2 --fix に任せる (リント違反のみ修正し、本文や GLFM 構文は書き換えない)。
  -- formatters_by_ft の値はリストなので deep-merge で「置換」され、extra の連鎖を上書きする。
  -- markdown.mdx (JSX 混在) は GLFM ではないため extra 既定 (prettier 含む) のまま残す。
  --
  -- 一部だけ整形: 整形したい行をビジュアル選択 (V) → <leader>cf。conform が選択範囲を
  -- 自動検出し、markdownlint-cli2 をバッファ全体に適用した上で「選択範囲に重なる差分だけ」反映する
  -- (markdownlint-cli2 は range 非対応だが conform が差分を範囲で絞る。範囲外は不変)。
  -- 注: markdownlint-cli2 はバッファに markdownlint 診断がある時のみ動作 (extra の condition)。
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        markdown = { "markdownlint-cli2", "markdown-toc" },
      },
    },
  },
}
