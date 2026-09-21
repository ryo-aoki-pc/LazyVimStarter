-- スペル候補を素の番号メニュー (z=) からピッカーに置き換える。
-- Snacks.picker.spelling は snacks.nvim に実装済みだが LazyVim はキーを割り当てていない。
-- 日英混在の文章では候補が多くなりがちで、絞り込みとプレビューがあるだけで実用度が変わる。
-- spelllang = { "en", "cjk" } とは競合しない (cjk は CJK を誤り扱いしないだけで、
-- 候補自体は英単語のまま)。追加の依存は無い。
return {
  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      {
        "z=",
        function()
          Snacks.picker.spelling()
        end,
        desc = "スペル候補 (ピッカー)",
      },
    },
  },
}
