# 変更後の確認

## GitLab Markdown 整形器の回帰テスト

- 整形器を開発するときに行う。setup-notes の安全な整形の導入 ([AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の安全な-markdown-整形を導入する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の安全な-markdown-整形を導入する)) を先に済ませる
- Node.js 22 以上と、インストール済みの conform.nvim が必要

1. AlmaLinux 10 では、説明リスト・GLFM 記法・設定の引き継ぎと Neovim の配線を確かめる。

   ```bash
   GLFM_FORMAT_RUNTIME_DIR="$HOME/.local/share/nvim/glfm-format" node --test ~/.config/nvim/tools/glfm-format/test/*.test.mjs
   nvim --headless -u NONE -i NONE -l ~/.config/nvim/tools/glfm-format/test/conform.lua
   ```

   - Node のテストがすべて通り、Neovim が `GLFM conform / installer integration: PASS` を出せばよい
   - Neovim の確認では lazy.nvim の導入・更新を起動しない

1. Windows 11 では、(この節の手順 1 の代わりに) 同じ回帰テストを実行する。

   ```powershell
   $env:GLFM_FORMAT_RUNTIME_DIR = "$env:LOCALAPPDATA\nvim-data\glfm-format"
   $glfm_test_files = (Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\nvim\tools\glfm-format\test" -Filter '*.test.mjs').FullName
   node --test $glfm_test_files
   nvim --headless -u NONE -i NONE -l "$env:LOCALAPPDATA\nvim\tools\glfm-format\test\conform.lua"
   ```

   - 期待する結果はこの節の手順 1 と同じ
