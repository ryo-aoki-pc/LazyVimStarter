-- Markdown の表 (パイプ表) の体裁を整える: vim-table-mode
-- prettier を外した代わりに「表だけ」を GLFM 安全・CJK(全角)幅対応で整形する手段。
-- 表 (| 行) のみ操作し、数式 $...$・脚注・[[_TOC_]]・本文には触れない。桁揃えは
-- strdisplaywidth() ベースで全角=2セル計算なので日本語混在でも崩れない。純 Vimscript・外部依存なし。
return {
  "dhruvasagar/vim-table-mode",
  ft = "markdown", -- markdown バッファでのみ読み込む
  cmd = { "TableModeToggle", "TableModeEnable", "TableModeDisable", "TableModeRealign", "Tableize" },
  init = function()
    -- g: 変数は plugin 読込前に設定する (起動時に既定値として参照されるため init で行う)。
    -- GFM/GLFM 形式のパイプ表: 角・外枠を '|'、区切りを '-'、整列記号 ':' (|:---|---:| を維持)。
    vim.g.table_mode_corner = "|"
    vim.g.table_mode_corner_corner = "|"
    vim.g.table_mode_fillchar = "-"
    vim.g.table_mode_header_fillchar = "-"
    vim.g.table_mode_align_char = ":"
    -- グローバル副作用を排除:
    vim.g.table_mode_always_active = 0 -- '|' のグローバル乗っ取りをしない (toggle 時のみ有効)
    vim.g.table_mode_disable_mappings = 1 -- 既定の <Leader>t* グローバルマップ群を無効化 (下で md 限定に張り直す)
  end,
  -- ft="markdown" 指定でバッファローカル化 → 他 filetype や将来の test extra と衝突しない。
  -- コマンドは disable_mappings に関係なく常に定義されるため <cmd> 直叩きで動く。
  keys = {
    { "<leader>tr", "<cmd>TableModeRealign<cr>", ft = "markdown", desc = "Table: 整形 (realign)" },
    { "<leader>tm", "<cmd>TableModeToggle<cr>", ft = "markdown", desc = "Table: ライブ整形 toggle" },
  },
}
