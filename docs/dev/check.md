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

## GitLab プレビューの試験

- `lua/config/gitlab_preview/`・`lua/plugins/gitlab-preview.lua`・`tools/gitlab-preview/` を変えたときに行う
- 実行場所はこのリポジトリのルート。Node.js 22 以上と Neovim 0.12 以上が必要
- 自動試験は試験用の取得先と一時データを使い、実機の資産を入れ替えない。Markdown API のトークンは不要
- ページの試験は Playwright と Edge・Chrome・Chromium のいずれかを使う。Playwright を通常の場所から読み込めないときは `PLAYWRIGHT_MODULE` に導入先を指定する
- ブラウザを自動検出できないときは `EDGE_BIN` または `CHROME_BIN` に実行ファイルを指定する。試験から依存やブラウザを自動で入れることはない

1. Node.js で、導入処理とブラウザの表示を確かめる。

   ```sh
   node --test tests/gitlab_preview_install.test.mjs tests/gitlab_preview_page.test.mjs
   ```

   - 失敗が 0 件ならよい。依存やブラウザの未検出による skip は合格に数えず、表示の試験は未実施として扱う
   - 導入処理は取得・再実行・破損修復・旧版保持・ハッシュ不一致・中断・同時実行を確認する
   - ページは公式スタイルの有無、テーマ・幅、資産の更新、SVG、スクロールの追従を確認する

1. Neovim で、資産の検証と配信を確かめる。

   ```sh
   nvim --headless -u NONE -i NONE -l tests/gitlab_preview_assets.lua
   nvim --headless -u NONE -i NONE -l tests/gitlab_preview_server.lua
   nvim --headless -u NONE -i NONE -l tests/gitlab_preview_integration.lua
   ```

   - すべて終了コード 0 ならよい
   - lazy.nvim の導入・更新を起動せず、資産のマニフェスト、配信範囲、CSP、GET・HEAD を確かめる
   - 模擬の Markdown API と実際の HTTP・SSE で、描画方式とスタイルの分離、導入後の更新、明示的なコマンドの登録も確かめる

1. ブラウザで、本物の資産を使うプレビューを確かめる。

   - 正本の導入手順で公式スタイルを取得した環境で、Markdown を開き `<leader>cp` を押す
   - 日本語の長文・見出し・通常と HTML の表・コード・目次・脚注・アラート・タスク・折りたたみを、GitLab.com と同じ本文幅・倍率で比べる
   - システム配色・ライト・ダーク、全幅・固定幅、狭い画面・広い画面で表示とスクロールを確かめる
   - `md-table-sticky` の全幅パネルを開いたまま、本文更新・テーマ変更・幅変更を行い、配色と表の操作を確かめる
   - API の表示と近似表示を別々に確かめ、ブラウザのネットワーク欄とコンソールでフォントの読込・資産の取得失敗・CSP 違反を確認する
   - 実施日・対象版・環境・出力・未実施の範囲は非公開の検証記録に残す
