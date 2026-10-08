# 💤 LazyVim 設定 (日本語編集 + Markdown 執筆向け)

[LazyVim](https://github.com/LazyVim/LazyVim) をベースに、日本語の入力・検索と Markdown (GLFM) 執筆を強化した Neovim 設定。対象は AlmaLinux 10 + GNOME と Windows 11。

## 手順書

初めてのマシンでは、自分の OS の導入手順を上から順に実行する。外部コマンド・日本語入力・フォントの導入から初回起動までを同じ手順書で扱う。

| 目的 | 読む文書 |
|---|---|
| AlmaLinux 10 に導入する | [導入手順](docs/setup.md#almalinux-10-に導入する-1-度だけ) |
| Windows 11 に導入する | [導入手順](docs/setup.md#windows-11-に導入する-1-度だけ) |
| 別のマシンの変更を取り込む | [設定とプラグインの同期](docs/setup.md#ほかのマシンの変更を取り込む-繰り返し) |
| 任意機能を有効にする・更新する・戻す | [目的別の文書一覧](docs/README.md) |
| 検証の環境・結果・未確認事項を調べる | [導入の検証記録](docs/verification/setup.md)・[機能の検証記録](docs/verification/readme.md) |

Neovim 本体だけの導入は [setup-notes の手順書](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md)、この個人設定の導入は上の手順書を使う。

## 主なカスタマイズ

- 日本語入力: IME の切り替え、カーソル色・モード表示、変換中の入力を扱う
- 日本語検索: Migemo で検索と補完を行う
- Markdown / GLFM: 説明リストを保つ整形、GitLab プレビュー、画像の貼り付け、表の編集を行う
- SSH: ヤンクを手元のクリップボードへ送る

機能の操作・制約・設定方針は [機能と設定](docs/reference/configuration.md)、必要な外部コマンドは [導入前の一覧](docs/setup.md#必要なもの一覧)にある。初回起動の前に揃える。

## 文書の配置

[文書一覧](docs/README.md)から、実行手順・機能と背景・検証記録を選べる。設定を変更する場合は [開発ガイド](CLAUDE.md)も参照する。
