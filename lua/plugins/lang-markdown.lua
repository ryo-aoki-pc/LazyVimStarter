-- Markdown 言語サポート (LazyVim extra)
-- lazyvim.json は gitignore されているため、リポジトリで追跡できる import スペックで有効化する。
-- 内容: marksman LSP / markdownlint-cli2 + markdown-toc / conform (prettier 整形) /
--       nvim-lint + none-ls (lint 診断) / markdown-preview.nvim (<leader>cp) / render-markdown.nvim
return {
  { import = "lazyvim.plugins.extras.lang.markdown" },

  -- prettier の Markdown 整形: prose (本文) の改行を維持する。
  -- conform は formatters テーブルをマージするので、extra の markdown-toc /
  -- markdownlint-cli2 の条件や formatters_by_ft の順序はそのまま保たれる。
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        prettier = {
          prepend_args = { "--prose-wrap", "preserve" },
        },
      },
    },
  },
}
