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
