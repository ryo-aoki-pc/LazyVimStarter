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
--
-- ※ ステージ/取り消し後、右の gitsigns 符号は即時更新されるが、左右の side-by-side 表示は
--   自動更新しない (理由は下の watch_index コメント参照)。最新表示が要るときはパネルの R か
--   :DiffviewRefresh で手動更新する。
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
      -- watch_index を無効化する理由 (重要):
      -- diffview の watch_index (既定 on) は .git/index の変化を検知してビューを自動再描画する。
      -- だがこの再描画で作業ツリーバッファが再読込/差し替えされ、gitsigns が detach→再 attach
      -- される。gitsigns の undo_stage_hunk (= <leader>ghu) は「その attach セッション中に
      -- ステージした hunk のスタック (staged_diffs)」を辿って取り消す実装なので、再 attach で
      -- スタックが消えると「ステージはできるが取り消せない」状態になる (特に Windows で発生)。
      -- 自動再描画を切ることで gitsigns の attach とスタックが保持され、ステージ/取り消しの両方が
      -- 安定して動く。トレードオフとして、左 (index) 側の side-by-side 表示はステージ後に自動
      -- 更新されない (gitsigns の符号は stage 直後に即時更新される)。最新の差分表示が欲しいときは
      -- パネルの R / :DiffviewRefresh で手動更新する (手動更新時はスタックがリセットされる点に注意)。
      watch_index = false,
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
      -- diffview が diff バッファを読み込むたびに、左右の「実ファイル (作業ツリー) 側」
      -- バッファへ gitsigns が attach していなければ attach する (保険)。
      -- 重要: 既に attach 済みなら何もしない。ここで無条件に再 attach すると undo_stage_hunk
      -- が使う staged_diffs スタックを消してしまい、取り消しが効かなくなるため。
      -- index 側 (diffview:// 仮想バッファ) は実ファイルではないので name で除外する。
      hooks = {
        diff_buf_read = function(bufnr)
          local name = vim.api.nvim_buf_get_name(bufnr)
          if vim.bo[bufnr].buftype ~= "" or name == "" or name:match("^diffview://") then
            return
          end
          local ok, gs_cache = pcall(require, "gitsigns.cache")
          local attached = ok and gs_cache.cache and gs_cache.cache[bufnr] ~= nil
          if not attached then
            pcall(function()
              require("gitsigns").attach(bufnr)
            end)
          end
        end,
      },
    },
    -- 補足: 以前ここには "GitSignsChanged → DiffviewRefresh" autocmd があったが削除した。
    -- DiffviewRefresh / 自動再描画は作業ツリーバッファを再読込して gitsigns を detach させ、
    -- gitsigns の attach・staged_diffs スタックを壊す (= ステージ後に取り消せない / Windows で
    -- 右ペインのキーマップが失われる) 原因になっていたため。表示の自動更新 (watch_index) も
    -- 上の opts で無効化し、安定動作を優先している。
    -- opts はテーブルなので LazyVim が require("diffview").setup(opts) を自動実行する。
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
