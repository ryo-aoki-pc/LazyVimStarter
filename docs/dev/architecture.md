# 設定の仕組み (IME 連携・日本語の検索・Markdown / GLFM)

[AGENTS.md](../../AGENTS.md) の「アーキテクチャ」から分けた節。AGENTS.md を Codex が読める大きさ (32 KiB) に収めるため、ここに置く。下のファイルを変える前に読む。

## IME 連携 (この設定で最も複雑な部分)

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

## Markdown / GLFM

`lua/plugins/lang-markdown.lua` が extra `lang.markdown` を上書きする。

- 整形連鎖から **prettier を除外**し、`glfm_markdownlint` にする
  (prettier は GLFM の数式 `$...$`・複数行脚注・`[[_TOC_]]` を壊すため)。
  `tools/glfm-format/format.mjs` が markdownlint-cli2 の公式 API で修正候補を集め、Comrak の
  構文木で説明リストの対応・所属・本文を検査する。安全な修正は説明内部にも適用する。
  修正候補はまとめて当てて 1 回で検査し、構造が変わるときだけ半分に分けて原因を除く (修正ごとに
  文書全体を解析すると、違反の多い長い文書で保存の上限を超えるため)。markdownlint の設定は、
  以前の `markdownlint-cli2 --fix` と同じく Neovim の作業ディレクトリを基準に探す (ファイルが
  その下にあるとき。上の階層のプロジェクト設定も効く)。
  固定した npm 依存は `stdpath("data")/glfm-format` に `:GlfmFormatInstall` で導入する。
  保存時に依存を自動取得しない。Node.js 22 以上が必要。conform の
  `formatters_by_ft` は `opts` 関数で明示代入して置き換え、`markdown.mdx` の連鎖も全部書いている。
  Markdown / MDX だけ `timeout_ms=10000` (他は既定の 3000)。新規 AlmaLinux VM では
  単独整形が 3.01 秒で既定 timeout に掛かったため。名前付き timeout を持つ表はリストではなく
  deep-merge されるので、表の `opts` に戻すと extra の prettier 等が残る。
  実 UI の保存と GLFM 数式・目次の保持、連鎖・既定値を確認した (docs/verification/setup.md の新規 VM 記録)。
- フォーマッターの回帰テストは `tools/glfm-format/test/`。説明リストと GLFM 固有記法の
  保持・説明内部の安全な修正・設定の優先順位・冪等性・CLI の失敗時を確認する。説明の後に
  `>` だけの行 (空の引用) を足さないこと・上の階層の設定・末尾の空行・小文字の目次・
  シンボリックリンク経由の起動も確かめる。Windows 11 の実機・Neovide の実キー・gitlab.com の
  描画での確認は docs/verification/setup.md の付録にある。
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

