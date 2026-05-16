return {
  {
    "vim-denops/denops.vim",
    lazy = true,
  },
  {
    "vim-skk/skkeleton",
    dependencies = { "vim-denops/denops.vim" },
    event = { "InsertEnter", "CmdlineEnter" },
    config = function()
      require("config.skkeleton").setup()
    end,
  },
}
