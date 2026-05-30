-- Markdown 言語サポート (LazyVim extra)
-- lazyvim.json は gitignore されているため、リポジトリで追跡できる import スペックで有効化する。
-- 内容: marksman LSP / markdownlint-cli2 + markdown-toc / conform (prettier 整形) /
--       nvim-lint + none-ls (lint 診断) / markdown-preview.nvim (<leader>cp) / render-markdown.nvim
return {
  { import = "lazyvim.plugins.extras.lang.markdown" },
}
