# LazyVim の文書一覧

[リポジトリの概要](../README.md)

## 導入・運用

実行手順は [setup.md](setup.md) にまとめてある。自分の OS の導入から始め、以後は目的の節を使う。

| 目的 | 手順 |
|---|---|
| AlmaLinux 10 + GNOME に導入する | [AlmaLinux の導入](setup.md#almalinux-10-に導入する-1-度だけ) |
| Windows 11 に導入する | [Windows の導入](setup.md#windows-11-に導入する-1-度だけ) |
| ほかのマシンと設定・プラグインを揃える | [変更の取り込み](setup.md#ほかのマシンの変更を取り込む-繰り返し) |
| GLFM 整形器の依存を入れる | [安全な整形の導入](setup.md#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後) |
| 整形器を変更した後に確かめる | [回帰テスト](setup.md#gitlab-markdown-整形器の回帰テストを実行する-開発時) |
| tmux 内でもカーソル色を変える | [tmux の設定](setup.md#カーソル色を-tmux-で効かせる-任意) |
| GNOME の上部バーと IME を揃える | [GNOME 拡張](setup.md#gnome-の上部バーを-ime-連携に合わせる-任意) |
| GitLab プレビューを使う | [トークンの設定](setup.md#gitlab-プレビューのトークンを設定する-任意) |
| SSH 先のヤンクを手元へ送る | [クリップボード](setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意) |
| 本体・外部コマンド・プラグインを更新する | [更新](setup.md#更新) |
| 退避した設定へ戻す | [ロールバック](setup.md#ロールバック) |
| 導入前の状態・依存・完了条件を確認する | [前提・確認・対処](setup.md#前提確認対処) |

## 機能と背景

| 内容 | 文書 |
|---|---|
| 日本語入力・検索、Markdown、外部依存、lock の運用 | [機能と設定](reference/configuration.md) |
| 導入で採用した方法・背景・参照資料 | [導入の補足資料](reference/setup.md) |
| 設定の構成と変更時の注意 | [開発ガイド](../CLAUDE.md) |

## 検証記録

記録には対象版・環境・実施結果・未確認事項がある。現在の実行手順は上の導入・運用から選ぶ。

| 内容 | 文書 |
|---|---|
| 導入と任意機能の検証 | [導入の検証記録](verification/setup.md) |
| 機能と挙動の実測 | [機能の検証記録](verification/readme.md) |
| 開発ガイドから分離した従来の実測 | [開発時の検証記録](verification/claude.md) |
