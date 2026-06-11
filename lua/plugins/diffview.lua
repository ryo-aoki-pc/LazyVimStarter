-- git diff を左右分割 (side-by-side) で見ながらパッチ単位のステージングを行う: diffview.nvim
-- `:DiffviewOpen` (引数なし) は index と作業ツリーを比較し、右側は実ファイルそのものの
-- バッファなので LazyVim 標準の gitsigns キーマップがそのまま効く。つまり
-- 「差分を左右で見ながら git add -p」= diffview (表示) + gitsigns (ハンク操作) の組合せで実現する。
--
-- ■ パッチステージングの流れ
--   <leader>gd     : diff ビューを開く / 閉じる (トグル)
--   ]h / [h        : 次 / 前のハンクへ (diff ウィンドウ内では ]c / [c 相当で移動)
--   <leader>ghs    : カーソル位置のハンクをステージ。visual 選択中は選択行のみ = 部分ステージ
--   <leader>ghu    : ステージ取り消し / <leader>ghr : ハンクを破棄 (作業ツリーを戻す)
--   ファイルパネル : - (または s) で stage/unstage トグル、S 全ステージ、U 全アンステージ、X 変更破棄
--   ステージ済みの確認はパネルの "Staged changes" セクション (HEAD↔index の差分が開く)
--   別手段: 左 (index) バッファは編集可能で、dp / do で差分を送ってから :w しても index に反映できる
return {
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    keys = {
      {
        "<leader>gd",
        function()
          -- スマートトグル: 現在のタブが diffview なら閉じ、そうでなければ開く
          if require("diffview.lib").get_current_view() then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Git Diff View (toggle)",
      },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Git File History (現在ファイル)" },
      -- visual では選択行範囲の履歴 (:'<,'>DiffviewFileHistory → git log -L 相当)
      { "<leader>gH", ":DiffviewFileHistory<cr>", mode = "x", desc = "Git File History (選択範囲)" },
    },
    opts = {
      -- diff2_horizontal が「2 窓を左右に並べる」レイアウト (2-way diff の既定値だが、
      -- side-by-side 表示がこの設定の主目的なので明示しておく)
      view = {
        default = { layout = "diff2_horizontal" },
        file_history = { layout = "diff2_horizontal" },
      },
      enhanced_diff_hl = true, -- 削除側 filler 等の diff ハイライトを強化
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 32 },
      },
      keymaps = {
        -- q で閉じられるのはパネルのみ。diff バッファ側はマクロ記録 (q) を潰さないため既定のまま
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Diffview を閉じる" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Diffview を閉じる" } },
        },
      },
    },
    config = function(_, opts)
      require("diffview").setup(opts)
      -- gitsigns でステージ / 取り消しした内容を即座にパネルと左 (index) バッファへ反映する。
      -- GitSignsChanged は「リポジトリ状態を変え得る操作」(stage 等) の後にのみ発火する。
      -- DiffviewRefresh は冪等なので余分に走っても安全 (手動更新はパネルの R でも可)。
      vim.api.nvim_create_autocmd("User", {
        pattern = "GitSignsChanged",
        group = vim.api.nvim_create_augroup("user_diffview_refresh", { clear = true }),
        callback = function()
          if require("diffview.lib").get_current_view() then
            vim.cmd("DiffviewRefresh")
          end
        end,
      })
    end,
  },

  -- LazyVim 既定の <leader>gd (Snacks "Git Diff (hunks)" ピッカー) は diffview に譲り、
  -- ピッカー自体は空いている <leader>gv へ退避して機能を残す
  -- (<leader>gD は "Git Diff (origin)" で使用済みのため避ける)。
  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      { "<leader>gd", false },
      {
        "<leader>gv",
        function()
          Snacks.picker.git_diff()
        end,
        desc = "Git Diff (hunks)",
      },
    },
  },
}
