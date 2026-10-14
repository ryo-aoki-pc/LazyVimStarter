# Neovim 設定 (LazyVim) の導入手順 (AlmaLinux 10 + GNOME / Windows 11)

Windows 11・AlmaLinux 10 の Neovim の導入・利用・更新手順は、setup-notes の `docs/neovim.md`（Neovim のセットアップ）に集約した。

### AlmaLinux 10 に導入する (1 度だけ)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の設定を導入する)

### Windows 11 に導入する (1 度だけ)

[Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の設定を導入する)

### ほかのマシンの変更を取り込む (繰り返し)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の設定とプラグインの版を揃える) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の設定とプラグインの版を揃える)

### GitLab Markdown の安全な整形を導入する (初回と依存の変更後)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の安全な-markdown-整形を導入する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の安全な-markdown-整形を導入する)

### GitLab Markdown 整形器の回帰テストを実行する (開発時)

- 整形器を開発するときに行う。[安全な整形の導入](#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後)を先に済ませる
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

---

## カーソル色を tmux で効かせる (任意)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-のカーソル色を-tmux-で使う)

## GNOME の上部バーを IME 連携に合わせる (任意)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の-ime-連携に-gnome-の上部バーを合わせる)

## GitLab プレビューのトークンを設定する (任意)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の-gitlab-プレビューを設定する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の-gitlab-プレビューを設定する)

## SSH 越しのヤンクを手元のクリップボードに送る (任意)

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-のヤンクを-ssh-越しに手元へ送る)

## 更新

[AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の本体外部コマンドプラグインを更新する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の本体外部コマンドプラグインを更新する)

## ロールバック

[元に戻す手順と問題への対処](extra/setup.md)

## 前提・確認・対処

[必要なもの・確認・対処](extra/setup.md#前提確認対処)

## 実施手順

[AlmaLinux 10 の設定導入](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の設定を導入する) / [Windows 11 の設定導入](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の設定を導入する)

### 実施前の状態

[関連情報](https://github.com/ryo-aoki-pc/LazyVimStarter/blob/custom/docs/extra/setup.md#実施前の状態)

### 必要なもの一覧

[関連情報](https://github.com/ryo-aoki-pc/LazyVimStarter/blob/custom/docs/extra/setup.md#必要なもの一覧)

### 完了時点の状態

[関連情報](https://github.com/ryo-aoki-pc/LazyVimStarter/blob/custom/docs/extra/setup.md#完了時点の状態)

### 注意点

[関連情報](https://github.com/ryo-aoki-pc/LazyVimStarter/blob/custom/docs/extra/setup.md#注意点)
