return {
  {
    "vim-denops/denops.vim",
    lazy = false,
  },
  {
    "vim-skk/skkeleton",
    lazy = false,
    dependencies = { "vim-denops/denops.vim" },
    build = ":call denops#cache#update(#{reload: v:true})",
    init = function()
      require("config.skkeleton").setup()
    end,
  },
}