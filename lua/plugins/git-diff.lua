-- Git 差分の side-by-side 表示と、ハンク単位 / 部分 (行範囲) 単位のステージング。
--   - neogit:   magit 風ステータスバッファ。ハンク単位および Visual 選択した行範囲だけの
--               部分ステージ/アンステージ (git add -p 相当) を担当する。
--   - diffview: 左右 (side-by-side) 差分描画を担当し、neogit に統合 (integrations.diffview) する。
--
-- lazy.lua の defaults.lazy=false のため、各 spec は cmd / keys を必ず指定して遅延ロードにする
-- (未指定だと起動時に読み込まれてしまう)。LazyVim 既定の gitsigns (<leader>gh*) はそのまま残し、
-- それらは作業バッファ上で動作して neogit/diffview と補完関係になる。
return {
  -----------------------------------------------------------------------------
  -- neogit: ステータスバッファ (ハンク/部分ステージング)
  -----------------------------------------------------------------------------
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim", -- 必須ユーティリティ。dependencies なので自動で lazy のまま入る。
      "sindrets/diffview.nvim", -- integrations.diffview=true 用。neogit から差分を diffview で開く。
    },
    cmd = "Neogit",
    keys = {
      -- ステータスバッファを開く。このバッファ内で <tab>=ファイル展開、s=ステージ、u=アンステージ。
      -- V で行選択してから s/u すれば「部分 (行範囲) ステージング」になる (neogit 既定動作)。
      { "<leader>gn", "<cmd>Neogit<cr>", desc = "Git: Neogit ステータス" },
    },
    opts = {
      kind = "tab", -- ステータスを別タブで開き、作業中レイアウトを壊さない。
      disable_hint = false, -- 上部のキーヒントを残す (s/u などを思い出しやすく)。
      graph_style = "unicode",
      integrations = {
        diffview = true, -- neogit の d キーで差分を diffview の side-by-side で開く。
        snacks = true, -- ピッカーを LazyVim 同梱 snacks に統合 (telescope/fzf を入れていないため)。
      },
    },
  },

  -----------------------------------------------------------------------------
  -- diffview.nvim: side-by-side 差分描画
  -----------------------------------------------------------------------------
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
      "DiffviewRefresh",
    },
    keys = {
      { "<leader>gD", "<cmd>DiffviewOpen<cr>", desc = "Git: Diffview (作業ツリー)" },
      { "<leader>gF", "<cmd>DiffviewFileHistory %<cr>", desc = "Git: ファイル履歴 (現在ファイル)" },
      { "<leader>gA", "<cmd>DiffviewFileHistory<cr>", desc = "Git: ファイル履歴 (全体)" },
    },
    opts = {
      enhanced_diff_hl = true, -- 語単位の差分ハイライトを強調。
      view = {
        -- diff2_horizontal = 横並び (左=旧/右=新)。既定値だが side-by-side を明示固定する。
        default = { layout = "diff2_horizontal" },
        merge_tool = { layout = "diff3_horizontal" },
        file_history = { layout = "diff2_horizontal" },
      },
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 35 },
      },
    },
  },
}
