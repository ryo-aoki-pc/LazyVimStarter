# AGENTS.md

このリポジトリで作業するコーディングエージェント（Claude Code・Codex・Grok Build）への指示。Claude Code は CLAUDE.md の `@AGENTS.md` で、Codex と Grok Build はこのファイルを直接読む。

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

Markdown 整形器の Node 回帰テストは `tools/glfm-format/test/` にある。CI・ビルドは無い。
整形器の導入・検証の実行手順は `docs/setup.md` にまとめる。ほかに使うのは以下。

```sh
# 整形 (stylua.toml = 2 スペース / 120 桁)。PATH には無く Mason 導入版を使う
# (Windows は $env:LOCALAPPDATA\nvim-data\mason\bin\stylua.cmd)
~/.local/share/nvim/mason/bin/stylua .

# headless での導入と検証。`!` を落とすと取得途中で +qa に殺される
nvim --headless +qa                    # 初回導入 (lazy-lock.json を書き換えるので、次の行で戻す)
git checkout -- lazy-lock.json && nvim --headless "+Lazy! restore" +qa   # lazy-lock.json に揃える
nvim --headless "+Lazy! load mason.nvim luamigemo" "+checkhealth lazyvim luamigemo" "+w! /tmp/lazyvim-health.txt" +qa
```

```vim
:checkhealth lazyvim   " 外部コマンドと treesitter の C コンパイラ
:checkhealth mason     " curl / tar / gzip と node / npm
:Lazy                  " プラグインの状態。:Lazy update 後は lazy-lock.json をコミットする
:Mason                 " markdownlint-cli2 / marksman 等
```

- `:checkhealth lazyvim` の `fzf is not installed` 警告は無視してよい (ピッカーは
  snacks.nvim の Lua 実装で fzf バイナリを呼ばない)。
- **headless では `UIEnter` が発火せず `VeryLazy` も来ない**ため、`lua/config/autocmds.lua`
  (IME 連携・CJK スペル・Markdown の conceal) は読み込まれない。それらの確認は通常どおり
  `nvim` を起動して行う。
- `lazy-lock.json` は追跡対象。`:Lazy update` で変化したらコミットする (別マシンは
  `:Lazy restore` で揃える)。`:Lazy sync` は update を含むので、揃えるだけのときは使わない。
- **初回導入は `lazy-lock.json` を書き換える**。lazy.nvim の起動時の導入は何回かに分かれ、1 回目の後に
  導入済みの分だけで lock を書き直す (`lazy/manage/lock.lua` の `update()`) ため、後から入るプラグインが最新になる。
  git で lock を戻してから `:Lazy restore` し直すと揃う (`docs/setup.md` の AlmaLinux 導入の手順 16)。
- `checkhealth lazyvim` を headless で見るときは、先に `mason.nvim` を読み込む (Mason の `bin` が PATH に
  入るのは Mason を読み込んだときだけで、読み込まないと `tree-sitter (CLI)` が ERROR になる)。

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

### IME 連携・日本語の検索・Markdown / GLFM

この設定で最も複雑な部分なので、[docs/dev/architecture.md](docs/dev/architecture.md) に分けてある。次のファイルを変える前に、その節を読む。

- 「IME 連携」: `lua/config/ime.lua`・`ime_indicator.lua`・`ime_preedit.lua`・`noice_cmdline.lua`、
  `lua/config/autocmds.lua` のモード遷移、`lua/config/keymaps.lua` の `<C-j>`、`lua/plugins/ime.lua`、
  `gnome-shell/` の拡張。日本語の検索 (Migemo) の `lua/config/migemo.lua`・`migemo_blink.lua`・
  `lua/plugins/migemo.lua` も同じ節
- 「Markdown / GLFM」: `lua/plugins/lang-markdown.lua`・`table-mode.lua`・`img-clip.lua`・`gitlab-preview.lua`、
  `lua/config/gitlab_preview/`、`snippets/markdown.json`、`tools/glfm-format/`、
  `lua/config/autocmds.lua` の Markdown の conceal

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
- lualine への追加は `lua/config/` ではなくプラグイン spec の `opts` 関数で行う。autocmd を張るのも
  `opts` の中にする: lazy.nvim が spec をまたいで合成するのは `opts` / `dependencies` / `cmd` /
  `event` / `ft` / `keys` だけで、`init` / `config` を書くと LazyVim 側の spec を丸ごと上書きする。
- blink.cmp の `cmdline.sources` はリストが spec 間でマージされず丸ごと置き換わる。
  `lua/plugins/migemo.lua` で blink 既定 (`buffer` `cmdline`) ごと書いているので、cmdline の
  ソースを足すときはそこに足す。
- 手順書や検証で GNOME / Anthy の設定を読み書きするときは `/usr/bin/gsettings` と書く。Homebrew の glib
  (cairo・ffmpeg・imagemagick などの依存で入る) の `gsettings` が PATH の先頭に来ると、dconf を使えずに
  `~/.config/glib-2.0/settings/keyfile` へ黙って書くので、GNOME にも Anthy にも効かない (実機で手順 15 が効いていなかった)。
  Anthy が実際に使うキー割り当ては、`/usr/share/ibus-anthy/setup` の `AnthyPrefs` で読むと確かめられる
- IME のキー (`<C-j>` など) を確かめるときは、キーを本物のキーボードから打つ。`--remote-send` や `nvim_input` は
  IBus を通らないので、Anthy がキーを食う不具合を見逃す
- GNOME Shell の拡張は内部の関数 (`_currentInputSourceChanged`) に頼る。GNOME を上げたら docs/setup.md の上部バーの節の
  手順 4 で確かめ、動けば `metadata.json` の `shell-version` に版を足す
- IME 連携を触るときは、対応環境が無くても静かに無効化される性質を壊さないこと
  (headless やコンテナで設定全体が落ちる)。
- タイマーなどから `:normal` を実行するプラグインは、挿入モードのまま `ModeChanged` の `i:n` / `n:i` を
  起こす (`InsertLeave` / `InsertEnter` は発火しない)。モード遷移に処理を張るときは `state()` の `m` で見分ける。
- noice (ext_messages) を使うと Neovim が `cmdheight` を 0 にするので、lualine は画面の最下段に来る。検索中は
  noice の検索欄 (`bottom_search`) が同じ最下段に重なって lualine を丸ごと覆う (zindex を上げても変わらない)。
  検索中に見せたい情報は lualine ではなく検索欄の側に出す (`ime_indicator.lua` の常時表示が実例)。
- Windows の `shell` は PowerShell なので、プラグインが `shell` 経由でカレントディレクトリのスクリプト
  (`install.cmd` など) を実行する処理は動かない (PowerShell は `.\` 無しでは実行しない)。build が失敗しても
  成功と表示されることがある。逆に img-clip.nvim は、`shell` が PowerShell なら PowerShell のコマンドを
  そのまま `vim.fn.system()` に渡すので、`shellcmdflag` の前置きの後ろに連結されて動いている。
- 改行は `.gitattributes` で LF に固定している。外すと、`core.autocrlf=true` の git (scoop の git の既定) で clone した
  Windows では、lazy.nvim が LF で書き直す `lazy-lock.json` の大きさが索引と食い違い、`git status` が `M` を出し続ける
  (`git diff` は空。手順書の「`git status --short` が何も出さなければ揃っている」が成り立たなくなる)。
- lazy.nvim は、無効にした (`enabled = false`) プラグインの行を `lazy-lock.json` に残し続ける。
  外したプラグインの行は手で消す。既に入っているマシンのディレクトリは `:Lazy clean` まで残る。
- LazyVim の mason.nvim の `ensure_installed` は spec をまたいで連結される (`opts_extend`)。
  ツールを外すときは opts 関数で取り除く。既に入っているツールは Mason が自動では消さない。
- スニペットの JSON で文字の `$` は `\\$` と書く (Neovim のスニペットの文法では `$` がタブストップになる)。
- `vim.uv` と `vim.system` のコールバックは fast context で走る。`vim.api` / `vim.fn` / `vim.fs` を呼ぶと
  エラーになるので、`vim.schedule` で通常の文脈に移してから呼ぶ (`lua/config/gitlab_preview/` が実例)。
- `lua/plugins/gitlab-preview.lua` の `virtual = true` は lazy.nvim の文書に無い機能。lazy.nvim を上げたら
  `<leader>cp` と `:GitLabPreview` が生きているか確かめる (だめなら snacks.nvim の spec の keys に相乗りさせる)。
- LazyVim は SSH の中では `clipboard` を空にし、Neovim は `clipboard` が空のときしか OSC 52 を自動で選ばないので、
  既定のままでは SSH 越しの `y` が手元に入らない (検出も端末頼みで、DA1 に `52` を出さない端末では noice が XTGETTCAP の
  応答を受け取らせない。WezTerm の nightly は DA1 に出す)。そのため `lua/config/options.lua` で、`SSH_CONNECTION`
  があるときだけ `g:clipboard` に OSC 52 (書き込みだけ。`p` は最後に送った内容を返す) を置き、`clipboard=unnamedplus` にしている。
  `clipboard` や `g:clipboard` を触るときはそこも見る。`p` で端末に問い合わせる形に戻すと、読み出しに応えない端末で 1 回ごとに 10 秒待つ。
- 長い日本語の文字列を含む行は、stylua の整形が 1 回で落ち着かないことがある (整形した結果を `--check` が
  また直せと言う)。そのときは行を分けるか文字列を短くする。
- `<leader>gg` の lazygit の `e` は `lua/plugins/lazygit.lua` が OS ごとに決める (Windows は `nvim` のプリセットで
  入れ子の Neovim、Linux は snacks 既定の `nvim-remote`)。lazygit は `editInTerminal` を明示するとプリセットの判定より
  優先するので、両方の OS で明示している。snacks は自分の設定を `LG_CONFIG_FILE` の最後に足すので、自分用の lazygit の
  config.yml より勝つ。Linux で `true` にすると、`e` の後に lazygit の窓が閉じずに残る。

## 既存ドキュメント

内容を重複させず、これらを参照・更新すること。**実行手順は `docs/setup.md` に一本化**して
あるので、README に手順を書き足さない。

- `docs/setup.md` — 新しいマシン (AlmaLinux 10 + GNOME / Windows 11) でのセットアップ手順書。
  `## 実施手順` の下を、シナリオの見出し (`###`、末尾の括弧に頻度) に分ける:
  「AlmaLinux 10 に導入する (1 度だけ)」手順 1〜19、「Windows 11 に導入する (1 度だけ)」手順 1〜11、
  「ほかのマシンの変更を取り込む (繰り返し)」手順 1〜2。後ろに「カーソル色を tmux で効かせる (任意)」
  「GNOME の上部バーを IME 連携に合わせる (任意)」「GitLab プレビューのトークンを設定する (任意)」「SSH 越しのヤンクを手元のクリップボードに送る (任意)」「更新」「ロールバック」(OS ごとの手順は
  「(この節の手順 N の代わりに)」)を置く。前提条件・注意・期待結果は手順書に残す。
  - 記法は `~/setup-notes` の `docs/dev/writing-rules.md` の「手順の形」「表現の規則」と kvm-container の `docs/setup.md` に揃える:
    太字にしない 1 行の説明「〜する。」→ ブロック → 箇条書き (末尾に「。」を付けない) 。
    止める手順は「**次の手順は、〜してから貼る**」で終える。アラートは最上位だけに 5 個まで
  - 変数は無い (設定の置き場所と clone 元の URL は変える必要が無いので、コマンドに直接書く)。
    例外は GitLab プレビューのトークンの節だけで、トークンと GitLab の URL は文書に書かず、貼った人に入力させる。
    AlmaLinux 10 のブロックは bash、Windows 11 のブロックだけ PowerShell (5.1 でも通る書き方にし、`&&` / `||` を使わない)
  - 手順は「AlmaLinux 導入の手順 N」「Windows 導入の手順 N」「取り込みの手順 N」と呼び、シナリオの見出しへリンクする。
    番号を変えたら、本文・補足・付録・`> [!IMPORTANT]`・README・この欄を付け替える
  - 背景説明は `docs/reference/setup.md`、検証記録は `docs/verification/setup.md`。必要なもの一覧・前提条件・操作上の注意・期待結果は手順書に残す。過去の記録はリンクと手順番号以外を書き直さない
  - 検証済みとする範囲は `docs/verification/setup.md` に記載する。開発ガイドにあった従来の要約は `docs/verification/claude.md` に保存する

- `README.md` — この設定で何ができるかの説明。機能の挙動と設計上の判断、運用上の注意。

## 手順書と記録の分離

- 実行・更新・ロールバック・再実行用の確認手順には、必要な前提・注意・分岐・待機条件・期待結果だけを載せる
- 検証の環境・実施日・対象コミット・実出力・結果・未確認事項は `docs/verification/<手順書名>.md`、背景説明は必要なときだけ `docs/reference/<手順書名>.md` に置く。README は `readme.md` を使う
- 既存の記録の本文を保持して移動し、ファイルと見出しへの参照を更新する。再実行できる確認コマンドを実施済みの記録と混同しない

## 共同作業の規則

このリポジトリでは、Claude Code・Codex・Grok Build が同じ規則で作業する。分担と `custom` への取り込みは人が決める。

- 起動された worktree（作業ディレクトリ）の中だけでファイルを変える。ほかの worktree のファイルは変えない
- 今のブランチにだけコミットする。`custom` にはコミットも push もしない
- 頼まれた範囲のファイルだけを変える。範囲の外を変えるときは、変える前に理由を書いて確かめる
- 終わったら、テストとリンターを通してから、目的ごとにコミットする。通らなければコミットせずに、結果を報告する
- コミットしたら、今のブランチを push し、`custom` への Pull Request を作る（既にあれば足す）。`custom` への取り込み（マージ）とブランチの削除は人が行う。今のブランチに `custom` を取り込むのは、頼まれたときと、Pull Request が競合したときだけ
- 秘密情報（`.env`・鍵・トークン・パスワード）を読まない・書かない・出力しない
- レビューを頼まれたら、ファイルを変えずに、指摘を「重大度・場所（ファイル:行）・理由・直し方」で挙げる
- ほかの担当の変更は、`git diff custom...agent/codex` のように git で読む（ほかの worktree へ移らない）
- `main` は上流の追従用。上流の追従を頼まれたとき以外は変えない
