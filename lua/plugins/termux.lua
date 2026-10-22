-- Android の Termux だけの設定 (setup-notes の docs/android.md の「Termux の Neovim」)。ほかの OS では何もしない。
-- Termux は bionic libc なので、Mason が入れる glibc 向け・静的なバイナリ (lua-language-server・stylua・
-- shellcheck・shfmt・taplo・marksman) は起動できない。それらは Termux のパッケージ (pkg) で入れたものを使う。
-- npm で入る Mason の道具 (bash-language-server・json-lsp・yaml-language-server・markdownlint-cli2) はそのまま使える。
local is_termux = vim.fn.has("termux") == 1
if not is_termux then
  return {}
end

-- Mason に自動で入れさせない道具。Termux のパッケージを使う (tree-sitter CLI のパッケージ名は tree-sitter)。
local pkg_tools = { "stylua", "shfmt", "shellcheck", "taplo", "marksman", "lua-language-server", "tree-sitter-cli" }

local function has(cmd)
  return vim.fn.executable(cmd) == 1
end

return {
  {
    "neovim/nvim-lspconfig",
    -- Mason の自動導入を止め、PATH にある LSP だけを使う。無ければ起動の警告も出さない。
    opts = {
      servers = {
        lua_ls = { mason = false, enabled = has("lua-language-server") },
        taplo = { mason = false, enabled = has("taplo") },
        marksman = { mason = false, enabled = has("marksman") },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      -- 既に Mason の版が入っていても、Termux のパッケージの道具を先に見つける。
      opts.PATH = "append"
      -- ensure_installed は spec 間で連結されるので、合成後の一覧から opts 関数で取り除く。
      -- npm で入る道具は Termux でも使えるため残す。
      opts.ensure_installed = vim.tbl_filter(function(name)
        return not vim.tbl_contains(pkg_tools, name)
      end, opts.ensure_installed or {})
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    -- Android 向けの事前ビルドは端末のアーキテクチャに合うとは限らないため、Lua の実装を使う。
    opts = { fuzzy = { implementation = "lua" } },
  },
}
