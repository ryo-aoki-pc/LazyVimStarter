-- IME の状態表示。制御そのものは lua/config/ime.lua が持ち、ここは見た目だけを足す。
-- lualine の設定は LazyVim の ui.lua が所有しているため、この部分だけはプラグイン spec
-- (opts 関数による追記) にする必要がある。
return {
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      local sections = opts.sections
      if not sections or not sections.lualine_a then
        return
      end
      -- mode の直後に置く。端末のカーソル色は tmux の Cs/Cr 依存で当てにならないため、
      -- 確実に見えるインジケータはこちらを主とする。
      -- status() はキャッシュを読むだけなので、描画のたびに外部プロセスは起きない。
      table.insert(sections.lualine_a, 2, {
        function()
          return require("config.ime").status()
        end,
        cond = function()
          return require("config.ime").status() ~= ""
        end,
        padding = { left = 1, right = 1 },
      })
    end,
  },
}
