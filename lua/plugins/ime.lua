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
      -- IME の状態が変わったら即座に作り直す。lualine は前もって組み立てた文字列を 1 秒ごとのタイマーか
      -- カーソル移動などのイベントでしか作り直さないため、そのままだと <C-j> の後も あ / A が最大 1 秒
      -- 古いまま残る。ime.lua は状態が変わるたびに User ImeStateChanged を出す。
      -- autocmd を opts の中で張るのは、lazy.nvim が spec をまたいで合成するのは opts などに限られ、
      -- init / config を書くと LazyVim 側の spec (起動画面でステータスラインを隠す init など) を
      -- 上書きしてしまうため。opts は lualine を読み込む時に走る (augroup を clear するので重複しない)。
      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("user_ime_lualine", { clear = true }),
        pattern = "ImeStateChanged",
        callback = function()
          -- 既定の refresh は溜めておいて次の周期 (refresh_time) にまとめて描くので、force で今作り直す。
          pcall(function()
            require("lualine").refresh({ place = { "statusline" }, force = true })
          end)
        end,
      })
    end,
  },
}
