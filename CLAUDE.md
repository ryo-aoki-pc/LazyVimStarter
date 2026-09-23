# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリについて

LazyVim をベースにした Neovim 設定。リポジトリのルートが **Neovim の設定ディレクトリそのもの**
(`~/.config/nvim` / Windows は `%LOCALAPPDATA%\nvim`) で、ビルド成果物は無く、編集結果は
`nvim` を起動し直すと反映される。エントリポイントは `init.lua` の
`require("config.lazy")` 1 行だけ。

主眼は **日本語の入力・検索**と **Markdown (GLFM) 執筆**の強化。

### ブランチ構成 (重要)

| ブランチ | 内容 |
| --- | --- |
| `custom` | 実運用の設定。**作業ブランチはここ**。 |
| `main` | [LazyVim starter](https://github.com/LazyVim/LazyVim) の上流ミラー。upstream 追従以外では触らない。 |

`main` には `lua/plugins/example.lua` 等の starter 由来のファイルしか無い。以下の説明は
すべて `custom` の内容を指す。

コミットメッセージ・PR の説明・コード内コメントは**日本語**で書く。

## コマンド

テストスイート・CI・ビルドは無い。実際に使うのは以下。

```sh
# 整形 (stylua.toml = 2 スペース / 120 桁)。PATH には無く Mason 導入版を使う
~/.local/share/nvim/mason/bin/stylua .

# headless での検証。`!` を落とすと取得途中で +qa に殺される
nvim --headless "+Lazy! sync" +qa      # 初回導入
nvim --headless "+Lazy! restore" +qa   # lazy-lock.json に揃える
```

```vim
:checkhealth lazyvim   " 外部コマンドと treesitter の C コンパイラ
:checkhealth mason     " curl / tar / gzip と node / npm
:Lazy                  " プラグインの状態。:Lazy update 後は lazy-lock.json をコミットする
:Mason                 " markdownlint-cli2 / markdown-toc / marksman 等
```

- `:checkhealth lazyvim` の `fzf is not installed` 警告は無視してよい (ピッカーは
  snacks.nvim の Lua 実装で fzf バイナリを呼ばない)。
- **headless では `UIEnter` が発火せず `VeryLazy` も来ない**ため、`lua/config/autocmds.lua`
  (IME 連携・CJK スペル) は読み込まれない。それらの確認は通常どおり `nvim` を起動して行う。
- `lazy-lock.json` は追跡対象。`:Lazy update` で変化したらコミットする (別マシンは
  `:Lazy restore` で揃える)。

## アーキテクチャ

### 読み込み順

`init.lua` → `lua/config/lazy.lua`。`lua/config/options.lua` は lazy.nvim の起動前、
`keymaps.lua` と `autocmds.lua` は `VeryLazy` で読まれる。いずれも **LazyVim 既定の後**に
走るため、`options.lua` は `vim.opt.xxx:append()` で足りる (`formatoptions` の `mM`、
`matchpairs` の全角括弧が実例)。既定を消したいときだけ `remove()` してから入れ直す
(`diffopt` の `linematch` が実例)。

### LazyVim extra の有効化は `lua/config/lazy.lua` に集約

`lazyvim.json` は `.gitignore` 済みなので、**`:LazyExtras` の UI で有効化してもリポジトリに
残らない**。extra は必ず `lua/config/lazy.lua` の `spec` に `import` として書く。位置は
`lazyvim.plugins` の後・`{ import = "plugins" }` の前 (LazyVim が import 順をチェックする)。

現在: `lang.markdown` / `lang.json` / `lang.yaml` / `lang.toml` / `editor.dial` /
`ui.treesitter-context` / `lang.git` / `util.dot`。

### IME 連携 (この設定で最も複雑な部分)

OS の IME を Neovim のモードに追従させる仕組み。Neovim には `imactivatefunc` /
`imstatusfunc` が無いため、外部プロセス経由で IME デーモンを叩く自前実装になっている。
4 ファイルに分かれる。

- **`lua/config/ime.lua`** — 本体 (約 650 行)。ibus の global engine 名
  (`anthy` = 日本語 / `xkb:us::eng` = 英数) **だけ**を状態の真実とし、`busctl` / `gdbus` /
  `ibus` から使えるものを選んで D-Bus を直接叩く。バスアドレスは `~/.config/ibus/bus/` から
  自前で解決する (tmux が `WAYLAND_DISPLAY` を継承しないため既存プラグインは接続に失敗する)。
  状態は `GlobalEngineChanged` シグナルの購読で push され、ポーリングはしない。
  IME デーモンが居ない / headless / Windows でコマンドが無い環境では **静かに no-op** になる。
- **`lua/config/autocmds.lua`** — モード遷移の配線。`InsertLeave` ではなく `ModeChanged` の
  パターン (`i*:n` `R*:n` `*:c*` `c*:i*`) で拾う (`<C-c>` を取りこぼさず `i_CTRL-O` を除外する
  ため)。端末モードは `TermEnter` / `TermLeave`、終了・中断時は起動前の engine に戻す。
  理由はすべてファイル内のコメントにある。
- **`lua/plugins/ime.lua`** — lualine の `あ` / `A` 表示だけ。lualine の `opts` は LazyVim の
  `ui.lua` が所有しているため、表示の追加はプラグイン spec 側でしか行えない。
- **`lua/config/keymaps.lua`** — `<C-j>` トグル。**挿入モードとコマンドラインのみ**に張る
  (ノーマルモードの `<C-j>` は LazyVim のウィンドウ移動)。

コマンドライン (`:` `/`) は常に英数に落とすため、日本語の検索はローマ字のまま日本語に
マッチする Migemo が担う。この 2 つは対になっている。変換器は **`lua/config/migemo.lua`**
(純 Lua の luamigemo を呼ぶ。Deno などの外部ランタイムは不要)、配線は
**`lua/plugins/migemo.lua`** で `/` `?` の `<CR>`・flash.nvim の `s`・snacks picker の grep の
3 経路に入れている。入力がローマ字として読めるときだけ変換する。`*` `#` の日本語対応
(非 ASCII は `\<` `\>` なし) は `lua/config/keymaps.lua`。

### Markdown / GLFM

`lua/plugins/lang-markdown.lua` が extra `lang.markdown` を上書きする。

- 整形連鎖から **prettier を除外**し、`markdownlint-cli2 --fix` + `markdown-toc` のみにする
  (prettier は GLFM の数式 `$...$`・複数行脚注・`[[_TOC_]]` を壊すため)。
- 除外したい markdownlint ルールはファイル冒頭の `disabled_rules` に列挙する。空でない
  ときだけ設定 JSON を `stdpath("cache")` に生成し、**lint (nvim-lint) と整形 (conform) の
  両方**に `--config` を渡す (片方だけだと整形が lint の無効化を直し返す)。
- render-markdown.nvim は無効。プレビューは markdown-preview.nvim (`<leader>cp`)。
- 表の整形は `lua/plugins/table-mode.lua` (markdown バッファ限定、全角幅対応)。

### 日本語まわりの横断設定

`lua/config/options.lua` / `autocmds.lua` に散る。いずれも変更前にコメントを読むこと。

- `fileencodings` は先頭の `ucs-bom` が必須で、`cp932` はほぼ任意のバイト列を受理するため
  その後ろに推測用のエンコーディングを足しても到達しない。
- `ambiwidth` は既定 (`single`) のまま。**端末側の East Asian Ambiguous 幅設定と対で**
  変えないと、`○` `±` 等を含む行の桁が丸ごとずれる。
- 全角スペース (U+3000) は `matchadd` で可視化 (`listchars` では表現できない)。
- `spelllang` に擬似リージョン `cjk` を足して日本語を綴り誤り扱いから外す。
- Windows の `shell` は PowerShell (UTF-8 入出力、`shellredir` / `shellpipe` も上書き)。

## 変更時に踏みやすい地雷

- **prettier を持ち込む extra を足すと Markdown の整形が壊れる。** `formatting.prettier` や
  `lang.typescript` (推移的に import する) は `opts` 関数の中で `formatters_by_ft.markdown` に
  prettier を `table.insert` するため、`lang-markdown.lua` でのリスト置換の**後から**追記されて
  prettier が復活する。追加する際は必ず markdown の整形連鎖を確認する。
- extra は `:LazyExtras` ではなく `lua/config/lazy.lua` の import で足す (前述)。
- lualine への追加は `lua/config/` ではなくプラグイン spec の `opts` 関数で行う。
- IME 連携を触るときは、対応環境が無くても静かに無効化される性質を壊さないこと
  (headless やコンテナで設定全体が落ちる)。

## 既存ドキュメント

内容を重複させず、これらを参照・更新すること。**実行手順は `docs/setup.md` に一本化**して
あるので、README に手順を書き足さない。

- `docs/setup.md` — 新しいマシン (Windows 11 / AlmaLinux 10) でのセットアップ手順書。
  前半 `## 実施手順` は操作と短い注意だけ、理由・実測・落とし穴は後半の `## 補足` に置く
  構成 (`~/setup-notes` の記法に準拠)。外部依存の一覧と「つまずきやすい点」も補足にある。
- `README.md` — この設定で何ができるかの説明。機能の挙動と設計上の判断、運用上の注意。
