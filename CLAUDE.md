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

### IME 連携 (この設定で最も複雑な部分)

OS の IME を Neovim のモードに追従させる仕組み。Neovim には `imactivatefunc` /
`imstatusfunc` が無いため、外部プロセス経由で IME デーモンを叩く自前実装になっている。
7 ファイルに分かれ、GNOME の上部バーを合わせる GNOME Shell の拡張 (任意) が別にある。

- **`lua/config/ime.lua`** — 本体 (約 740 行)。ibus の global engine 名
  (`anthy` = 日本語 / `xkb:us::eng` = 英数) **だけ**を状態の真実とし、`busctl` / `gdbus` /
  `ibus` から使えるものを選んで D-Bus を直接叩く。バスアドレスは `~/.config/ibus/bus/` から
  自前で解決する (tmux が `WAYLAND_DISPLAY` を継承しないため既存プラグインは接続に失敗する)。
  状態は `GlobalEngineChanged` シグナルの購読で push され、ポーリングはしない。
  IME デーモンが居ない / headless / Windows でコマンドが無い環境では **静かに no-op** になる。
- **`lua/config/autocmds.lua`** — モード遷移の配線。`InsertLeave` ではなく `ModeChanged` の
  パターン (`i*:n` `R*:n` `*:c*` `c*:i*`) で拾う (`<C-c>` を取りこぼさず `i_CTRL-O` を除外する
  ため)。`i*:n` のうち `state()` に `m` が立つもの (挿入モードのまま実行された `:normal`。snacks の
  スムーズスクロールがアニメーションの 1 コマごとに起こす) は抜けたと見なさず、英数化を後回しにする。`i_CTRL-O` に入る時 (`i*:ni*` `R*:ni*`) と挿入からコマンドラインに入る時 (`<C-r>=` など) は
  sticky を記録し直す (戻る時に古い sticky で切り替わらないように)。コマンドラインから挿入以外へ抜ける時は
  `c*:*` で遷移先を見て英数に戻す。検索コマンドライン (`/` `?`) だけは `CmdlineEnter` / `CmdlineLeave`
  でバッファ単位の sticky を扱う (日本語への復元は入力待ちになってから。`*` `#` の検索では何もしない)。
  端末モードは `TermEnter` / `TermLeave`、終了・中断時は起動前の engine に戻す。
  理由はすべてファイル内のコメントにある。
- **`lua/plugins/ime.lua`** — lualine の `あ` / `A` 表示だけ。lualine の `opts` は LazyVim の
  `ui.lua` が所有しているため、表示の追加はプラグイン spec 側でしか行えない。lualine は前もって
  組み立てた文字列を 1 秒ごとのタイマーかカーソル移動などでしか作り直さないので、`ime.lua` が
  状態変化のたびに出す `User ImeStateChanged` を受けて即座に作り直させる。
- **`lua/config/ime_indicator.lua`** — `あ` / `A` の浮動ウィンドウを 2 つ持つ。`ime.lua` の `observe()`
  (値が実際に変わったときだけ通る) から呼ばれる。
  - 状態が変わった瞬間にカーソルの直下へ約 1 秒出す。挿入・置換・端末モードと検索 (`/` `?`) 以外では
    出さない (`<Esc>` の英数化は観測時点でノーマルモードなので出ない)。検索では noice の検索欄の窓に
    `bufpos` で合わせ、カーソルの 1 行上に出す。窓は開いた時点の位置に固定されるため、`CursorMovedI`・
    `CmdlineChanged`・`ModeChanged`・`WinLeave` で早めに消す。
    フォーカスが外れている間 (`FocusLost` から `FocusGained` まで) は出さず、その間に変わっていたら `FocusGained` で
    今の状態を出す。GNOME の Super+Space はキーボードを掴むので、WezTerm を直接使うと FocusLost → 切り替え →
    FocusGained の順で届き、出し直さないと Super+Space の表示が一度も出ない (実機で確認)。
  - 検索している間は、検索欄の右端に出し続ける。noice が ext_messages を使うと Neovim が `cmdheight` を
    0 にし (`ui.c` の `ui_refresh`)、lualine が最下段に来て、同じ最下段に出る noice の検索欄 (LazyVim の
    `bottom_search`) に覆われるため。`CmdlineEnter` / `CmdlineLeave` で開け閉めする (noice は検索欄を
    後から描くので、窓ができるまで少し待つ)。
  - コマンドラインの入力中は画面が自動で描き直されないので、開け閉めのたびに `noice_cmdline.redraw()` で描く。
- **`lua/config/noice_cmdline.lua`** — noice が描くコマンドラインの窓とカーソル位置の取得
  (`require("noice").api.get_cmdline_position()`) と、カーソルを検索欄に保ったままの描き直し
  (`nvim__redraw`)。`ime_preedit.lua` と `ime_indicator.lua` が使う。
- **`lua/config/keymaps.lua`** — `<C-j>` トグル。**挿入モードとコマンドラインのみ**に張る
  (ノーマルモードの `<C-j>` は LazyVim のウィンドウ移動)。
- **`gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com/extension.js`** — GNOME Shell の拡張 (任意。
  docs/setup.md の上部バーの節で入れる。Neovim の設定ではない)。GNOME Shell は ibus の engine が外から変わっても
  「今の入力ソース」(上部バー・Super+Space の MRU) を更新しないので、`GlobalEngineChanged` を受けて合わせる。
  `activateInputSource()` はキーボードを掴んで端末にフォーカスの出入りを起こすので使わず、内部の
  `_currentInputSourceChanged()` を呼ぶ。GNOME Shell 49.4 で確認 (`metadata.json` の `shell-version` は 49 だけ)。
- **`lua/config/ime_preedit.lua`** — Neovide 専用 (他では no-op)。Neovide は既定で IME の
  未確定文字列を描かないため、`neovide.preedit_handler` を差し替えてカーソル位置に inline の
  extmark で描く。`right_gravity = false` でないと挿入モードのカーソルが未確定文字列の前に出る。
  確定時は空の preedit による消去を遅らせ、確定文字列の挿入直前 (`InsertCharPre`) に消す
  (即座に消すと空白のフレームが、消さないと二重表示のフレームが一瞬描かれる)。描画は
  `vim.schedule` に回すので確定文字列の入力に追い越されうる。Neovide から届いた順をハンドラ内で
  数え (`commit_handler` も包む)、確定より前に送られた preedit は描かない。
  コマンドラインでは noice の cmdline バッファ (`noice_cmdline.cursor()`) に同じ extmark を置き、
  `noice_cmdline.redraw()` で描く (c モードでは通常のウィンドウが自動で描き直されない)。
  確定時は `CmdlineChanged` で消す。noice が無ければ描かない。

コマンドライン (`:` `/`) は英数で始めるため、日本語の検索はローマ字のまま日本語に
マッチする Migemo が担う (`/` `?` では `<C-j>` で直接打つこともでき、その状態は sticky)。
この 2 つは対になっている。変換器は **`lua/config/migemo.lua`**
(純 Lua の luamigemo を呼ぶ。Deno などの外部ランタイムは不要)、配線は
**`lua/plugins/migemo.lua`** で `/` `?` の `<CR>`・flash.nvim の `s`・snacks picker の grep・
検索コマンドラインの補完 (blink.cmp) の 4 経路に入れている。入力がローマ字として読めるときだけ
変換する。補完のソースは **`lua/config/migemo_blink.lua`** で、バッファ内の一致文字列を出現回数順に
候補にする (`/kensaku<Tab>`)。照合は ripgrep に標準入力で本文を渡して行う (Vim の正規表現は Migemo の
巨大なパターンに極端に遅い)。flash の `s` は `search.trigger = ";"` で `;` の後だけラベルが効き
(打ち足すローマ字とラベルの衝突を防ぐ)、1 文字ごとの変換は打ちかけのローマ字も扱う
`convert_incremental` を使う (子音だけの 1 文字目や、辞書の正規表現が長い `shi` `ka` などはまずかなだけで
探し、画面に一致が無いときだけ辞書を引く。辞書だと 1 打鍵に 100〜200ms かかる)。
一度一致が出た後に一致が無くなる打鍵では直前の一致を保ち、flash を終了させない。
`*` `#` の日本語対応 (非 ASCII は `\<` `\>` なし) は `lua/config/keymaps.lua`。

### Markdown / GLFM

`lua/plugins/lang-markdown.lua` が extra `lang.markdown` を上書きする。

- 整形連鎖から **prettier を除外**し、`markdownlint-cli2 --fix` だけにする
  (prettier は GLFM の数式 `$...$`・複数行脚注・`[[_TOC_]]` を壊すため)。conform の
  `formatters_by_ft` はリストが spec 間で置き換わるので、`markdown.mdx` の連鎖も全部書いている。
- **markdown-toc は外した** (npm の最終リリースが 2017 年)。整形連鎖から抜くのに加え、Mason の
  `ensure_installed` からも opts 関数で取り除く (LazyVim の mason.nvim の spec は `opts_extend` で
  リストを連結するので、テーブルで書いても消せない)。
- 除外したい markdownlint ルールはファイル冒頭の `disabled_rules` に列挙する。空でない
  ときだけ設定 JSON を `stdpath("cache")` に生成し、**lint (nvim-lint) と整形 (conform) の
  両方**に `--config` を渡す (片方だけだと整形が lint の無効化を直し返す)。
- render-markdown.nvim と **markdown-preview.nvim は無効** (後者は 2023-10 から更新が止まり、GLFM を描けない)。
  `lazy-lock.json` から markdown-preview.nvim の行は手で消した (lazy.nvim は無効にしたプラグインの行を残し続ける)。
- **プレビューは自作の GitLab プレビュー** (`<leader>cp`)。**`lua/config/gitlab_preview/`** が実体で、
  編集中の内容を curl で GitLab の Markdown API (`POST /api/v4/markdown`) に送り、返ってきた HTML を
  127.0.0.1 の HTTP サーバー (`vim.uv`) と SSE でブラウザのページに流す。分担と守ること:
  - `gitlab.lua` — 送り先と curl。**本文を送るのは `GITLAB_TOKEN` があるときだけで、送り先は `GITLAB_HOST`
    (無ければ gitlab.com) だけ**。git の remote のホスト名から送り先を推測しない (名前に gitlab を含む
    無関係なホストへトークンを送らないため)。remote は `project` を決めるのに使うだけ (ホストが一致するとき)。
    トークンは `--variable` で環境変数から curl に取り込ませ、コマンドラインにもファイルにも書かない (curl 8.3 以上)
  - `server.lua` — 127.0.0.1 だけで待ち受け、URL に推測できない token を入れる。Host と `Sec-Fetch-Site` を確かめる。
    リポジトリのファイルは `resolve()` で閉じ込める (`..`・`\`・ドライブ・デバイス名・`.git` を拒み、realpath が
    ルートの内側にあることを確かめる)。**`vim.uv` のコールバックは fast context** なので、ここでは `vim.api` /
    `vim.fn` / `vim.fs` を呼ばない (`vim.system` の終了のコールバックも同じ。`gitlab.lua` は `vim.schedule` で移す)
  - `init.lua` — 状態・autocmd・描画のループ (300ms で間引き、送信中の変更は 1 回にまとめ、古い応答は捨てる)。
    GitLab に送れないときは生の Markdown を送り、ページの markdown-it で近似表示にする
  - `page/` — ブラウザ側。GitLab のフロントエンドがする処理 (KaTeX・mermaid・遅延読み込みの画像) と、
    `data-canonical-src` (GitLab が残す書き換え前の相対リンク) を手元のファイルに戻す処理、スクロールの同期
  - `libs.lua` — ページが jsDelivr から読むライブラリの版と SRI。CSP もここから組み立てるので、
    **版を上げるときは url と sri を一緒に書き換える**
  - 配線は `lua/plugins/gitlab-preview.lua` の **lazy.nvim の virtual spec** (取得も runtimepath への追加もせず、
    lock にも載らない)。名前は `[1]` に書く (`name` だけだと lazy.nvim が不正な spec として捨てる)
- 画像の貼り付けは `lua/plugins/img-clip.lua` (img-clip.nvim、`<leader>ci`)。`relative_to_current_file` で
  .md の隣の `assets/` に保存する。ドラッグ & ドロップは切り、リポジトリの `.img-clip.lua` を dofile させない
  ように `get_config` を差し替えている (img-clip の内部関数。上げたら効いているか確かめる)。
- GLFM のスニペットは `snippets/markdown.json` (blink.cmp が `stdpath("config")/snippets` を自動で読む)。
  friendly-snippets と重ならないよう、名前は `gl` で始める。
- conceal も切っている (記法の記号を隠さない)。これだけは `lua/config/autocmds.lua` の
  `user_markdown_conceal` で、markdown を表示するウィンドウに `conceallevel=0` を setlocal する
  (`FileType` と `BufWinEnter` の両方で張る理由はコメント参照)。
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

## 既存ドキュメント

内容を重複させず、これらを参照・更新すること。**実行手順は `docs/setup.md` に一本化**して
あるので、README に手順を書き足さない。

- `docs/setup.md` — 新しいマシン (AlmaLinux 10 + GNOME / Windows 11) でのセットアップ手順書。
  `## 実施手順` の下を、シナリオの見出し (`###`、末尾の括弧に頻度) に分ける:
  「AlmaLinux 10 に導入する (1 度だけ)」手順 1〜19、「Windows 11 に導入する (1 度だけ)」手順 1〜11、
  「ほかのマシンの変更を取り込む (繰り返し)」手順 1〜2。後ろに「カーソル色を tmux で効かせる (任意)」
  「GNOME の上部バーを IME 連携に合わせる (任意)」「GitLab プレビューのトークンを設定する (任意)」「SSH 越しのヤンクを手元のクリップボードに送る (任意)」「更新」「ロールバック」(OS ごとの手順は
  「(この節の手順 N の代わりに)」) と `## 補足` を置く。
  - 記法は `~/setup-notes` の CLAUDE.md の「手順の形」「表現の規則」と kvm-container の `docs/setup.md` に揃える:
    太字にしない 1 行の説明「〜する。」→ ブロック → 箇条書き (末尾に「。」を付けない) → 折り畳みの補足 1 つまで。
    止める手順は「**次の手順は、〜してから貼る**」で終える。アラートは最上位だけに 5 個まで
  - 変数は無い (設定の置き場所と clone 元の URL は変える必要が無いので、コマンドに直接書く)。
    例外は GitLab プレビューのトークンの節だけで、トークンと GitLab の URL は文書に書かず、貼った人に入力させる。
    AlmaLinux 10 のブロックは bash、Windows 11 のブロックだけ PowerShell (5.1 でも通る書き方にし、`&&` / `||` を使わない)
  - 手順は「AlmaLinux 導入の手順 N」「Windows 導入の手順 N」「取り込みの手順 N」と呼び、シナリオの見出しへリンクする。
    番号を変えたら、本文・補足・付録・`> [!IMPORTANT]`・README・この欄を付け替える
  - 補足は「対象と検証環境」「実施前の状態」「必要なもの一覧」(README がリンク)「選択した方針」「完了時点の状態」
    「注意点」「参照」「付録」。付録 (検証記録) は書き直さない
  - 状態の要約 (補足の状態行を変えたらここも直す): AlmaLinux 10 は x86_64 のコンテナで、文書のブロックを
    そのまま貼って通した (aarch64 は未確認。検証した設定は PR #26 より前)。GNOME の実機では、導入済みの PC で
    置き場所を差し替えて導入の手順 16〜19 と取り込みの手順 1 (変更がある状態) を通した (手順 1〜15 は
    状態の確認だけ。パーサーとハイライト、カーソル直下と検索中の `あ` / `A`、img-clip、GitLab の近似表示と Firefox は確かめ、
    アイコンの字形と Firefox の表示は利用者が目で確かめた)。その後、利用者の本物のキーで、手順 15 が Homebrew の
    `gsettings` のせいで dconf に入っておらず日本語のときの `<C-j>` が Anthy に食われていたことが分かり、`/usr/bin/gsettings`
    で入れ直して直った。上部バーの拡張は画面の無い gnome-shell 49.4 で確かめ、本物のログイン・本物の Super+Space・
    トークンの節は未確認。Windows 11 は実機 (Windows 11 Pro) で、設定とデータの置き場所を
    差し替えて Windows PowerShell 5.1 に渡して通した (手順 2 とロールバックの手順 7 は未実行。IME の切り替えは
    モックの zenhan で確かめた。Neovide 0.16.2 の画面は、未確定文字列のハンドラを呼ぶ形で確かめ、本物の IME での入力は未確認。
    検索中の表示は、手順を通した後に Neovide と端末で個別に確かめた)。
    markdown-preview.nvim と markdown-toc を外し GitLab プレビュー・img-clip.nvim・GLFM のスニペットを足した変更は、
    Windows 11 の実機で置き場所を差し替え、模擬の GitLab API と headless の Edge で確かめた。本物のクリップボードの
    画像・既定のブラウザ・トークンの節の Windows の手順 (模擬のトークン)・gitlab.com の 401 も確かめ、本物の GitLab で
    表示できることはマージの後に利用者が確かめた (本物の GitLab での記法ごとの見え方と、トークンの節の AlmaLinux の手順は未確認)。
    SSH 越しのクリップボード (OSC 52) は、コンテナで tmux を手元の端末の代わりにして確かめた後、AlmaLinux 10 の実機で
    WezTerm の nightly (画面の無い mutter の上) から ssh し、SSH の節のブロックをそのまま貼って通した (Windows の WezTerm、
    GNOME にログインした画面、PAM を通すシステムの sshd は未確認)。取り込みの手順 1 は AlmaLinux 10 の実機で、使っている
    設定に対して行った (増えたプラグインを起動時に入れると lock が書き直され、`checkout` して `restore` し直すと揃うことを含む)
- `README.md` — この設定で何ができるかの説明。機能の挙動と設計上の判断、運用上の注意。
