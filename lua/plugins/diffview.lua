return {
  -- diffview.nvim: git diff を左右2ペイン(side-by-side)で閲覧する差分ブラウザ。
  -- hunk 単位の stage/unstage は右ペイン(実ファイル)上の gitsigns 既存キーで行う(下の autocmd で即時更新)。
  {
    "sindrets/diffview.nvim",
    -- 差分ブラウザは常駐不要。コマンド/キー起動でのみ読み込む。
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    opts = {
      enhanced_diff_hl = true, -- 既定 false。語句単位の追加/削除ハイライトを強調。
      file_panel = {
        listing_style = "tree",
        win_config = { position = "left", width = 35 },
      },
      view = {
        -- A(左)=index/HEAD、B(右)=working tree の左右2ペイン表示。
        default = { layout = "diff2_horizontal" },
        file_history = { layout = "diff2_horizontal" },
      },
      -- keymaps はあえて未指定(diffview 既定を使用)。バージョン差異の出やすい箇所を上書きしない方針。
      -- file panel 既定キー: `-` stage/unstage トグル, `S` 全 stage, `U` 全 unstage, `X` 破棄,
      --                      `<Tab>`/`<S-Tab>` 次/前ファイル, `<CR>`/`o` 開く, `i` tree<->list 切替。
    },
    keys = {
      -- side-by-side 差分ブラウザのトグル(開いていれば閉じる)。
      {
        "<leader>gd",
        function()
          if require("diffview.lib").get_current_view() then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Diffview (side-by-side, toggle)",
      },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current file)" },
      -- ビジュアル選択した行範囲の履歴(git log -L 相当)。
      { "<leader>gH", "<esc><cmd>'<,'>DiffviewFileHistory<cr>", mode = "x", desc = "File History (selection)" },
      { "<leader>gL", "<cmd>DiffviewFileHistory<cr>", desc = "File History (repo)" },
    },
  },

  -- LazyVim 既定の <leader>gd (Snacks "Git Diff (hunks)" picker) を無効化し、diffview トグルに明け渡す。
  -- picker 自体は <leader>gD に退避。optional=true で snacks を新規導入せず既存スペックにマージするだけ。
  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      { "<leader>gd", false },
      {
        "<leader>gD",
        function()
          Snacks.picker.git_diff()
        end,
        desc = "Git Diff (hunks)",
      },
    },
  },
}
