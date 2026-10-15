# 変更後の確認

## Markdown の整形の配線の試験

- `lua/config/md_format.lua`・`md_format_spare.lua`・`lua/plugins/lang-markdown.lua` を変えたときに行う。setup-notes の安全な整形の導入 ([AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の安全な-markdown-整形を導入する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の安全な-markdown-整形を導入する)) を先に済ませる
- インストール済みの conform.nvim が必要。整形器そのものの試験は [md-format](https://github.com/ryo-aoki-pc/md-format) のリポジトリにある

1. AlmaLinux 10 では、conform と予備のプロセスの配線を確かめる。

   ```bash
   nvim --headless -u NONE -i NONE -l ~/.config/nvim/tests/md_format_conform.lua
   ```

   - Neovim が `md-format conform integration: PASS` を出せばよい
   - Neovim の確認では lazy.nvim の導入・更新を起動しない
   - md-format を既定でない場所に入れたときは、`MD_FORMAT_DIR` にその導入先を設定してから実行する

1. Windows 11 では、(この節の手順 1 の代わりに) 同じ試験を実行する。

   ```powershell
   nvim --headless -u NONE -i NONE -l "$env:LOCALAPPDATA\nvim\tests\md_format_conform.lua"
   ```

   - 期待する結果はこの節の手順 1 と同じ
