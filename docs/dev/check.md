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

## 表の Excel 編集の配線の試験

- `lua/config/mdtable.lua`・`lua/plugins/mdtable.lua` を変えたときに行う
- 実行場所はこのリポジトリのルート。lazy.nvim は起動せず、Excel と mdtable の導入も要らない

1. コマンドとキー、端末へ渡す引数、保存と通知を確かめる。

   ```sh
   nvim --headless -u NONE -i NONE -l tests/mdtable_edit.lua
   ```

   - `mdtable edit integration: PASS` と終了コード 0 を確かめる
   - Windows では `:MdTableEdit` と markdown 限定の `<leader>te`、Windows 以外では空の spec になることを確かめる
   - 空白と日本語を含む絶対パス、`--table L<行>`、未保存の変更の保存、保存済みのバッファを書き直さないことを確かめる
   - Markdown のファイルでないバッファ・ファイル名が無い場合・読み取り専用の場合・mdtable が無い場合・保存できない場合は、端末を開かず通知することを確かめる
   - `Snacks` と実行ファイルの検索を差し替えるので、Excel と mdtable は起動しない
   - 一時データは作業ツリー内の `.tests/` に作り、試験後に消す。stylua と `git diff --check` も通す

## GitLab プレビューの試験

- `lua/config/gitlab_preview/init.lua`・`lua/plugins/gitlab-preview.lua` を変えたときに行う
- 実行場所はこのリポジトリのルート。`Neovim` 0.12以上と `Node.js` 22以上が必要
- 本物の `md-preview` やブラウザ、公式資産は使わず、通信もしない。Node.js で動く偽のアプリ
  `tests/gitlab_preview_bridge/fake-app.mjs` を `vim.g.gitlab_preview_command = { "node", <偽のアプリの絶対パス> }`
  で起こし、受けた JSON の行を記録して、試験が指定した ready・clients・jump・error を返す。
  実行ファイルの探索では PATH の検索結果とホームを差し替え、本物の `~/.local/bin` を見ない

1. 橋渡しの試験を行う。

   ```sh
   nvim --headless -u NONE -i NONE -l tests/gitlab_preview_bridge.lua
   ```

   - 「GitLab プレビューの橋渡し: 成功…件・失敗0件・skip0件」と終了コード0を確かめる
   - `Node.js` が無いときは未実施と表示する。skip は合格に数えない
   - hello と表示の初期値、分割された応答、doc のパス・表示名・本文・changedtick、間引きと追従、scroll を確かめる
   - コマンドの設定の文字列・並び・無効な値、PATH と決まった場所の優先順位、Windows の `.exe` の判定、
     未導入の知らせを1回だけ出すこと、起動失敗の知らせと復旧も確かめる
   - pause・resume とタブの再接続待ち、jump の窓・行・未知のパス、誤りのまとめ、起動の時間切れと版の違い、
     子の異常終了からの再起動、標準入力を閉じる終了、公式スタイルの導入の成功・失敗・進行中も確かめる
   - 一時データは作業ツリー内の `.tests/` に作り、試験後に消す。`lazy.nvim` の導入・更新や、実機の公式資産の変更は行わない

1. 関連する設定を整形し、Markdown の整形の配線も保たれていることを確かめる。

   ```sh
   nvim --headless -u NONE -i NONE -l tests/md_format_conform.lua
   ```

   - 前の「Markdown の整形の配線の試験」の導入条件に従う
   - stylua（2スペース・120桁）と `git diff --check` も通す
   - 実際の描画・ページ・公式資産の検証は `md-preview` 側の試験で行う
