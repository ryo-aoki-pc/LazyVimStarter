# 💤 LazyVim 設定 (日本語編集 + Markdown 執筆向け)

[LazyVim](https://github.com/LazyVim/LazyVim) をベースに、日本語の入力・検索と
Markdown (GLFM) 執筆を強化した Neovim 設定。

**新しいマシンで動かすまでの手順は [docs/setup.md](docs/setup.md)** にある
(外部コマンドの導入、GNOME + ibus の初期設定、初回起動と動作確認まで)。
この README は「何ができる設定か」を説明する。


## 手順書

- 手順書は [docs/setup.md](docs/setup.md) の 1 本。`## 実施手順` の下で、OS ごとの導入 (1 度だけ) と、
  ほかのマシンの変更の取り込み (繰り返し) を見出しで分けてある
- 初めてのマシンでは、自分の OS の「導入する」を上から順に貼る。以後は、必要なシナリオと節だけを貼る
- 対象は AlmaLinux 10 + GNOME と Windows 11。実施範囲は [導入の検証記録](docs/verification/setup.md)、README の実測は [別の記録](docs/verification/readme.md) に書いてある

| 節 | 頻度 | 用途 |
|---|---|---|
| [AlmaLinux 10 に導入する](docs/setup.md#almalinux-10-に導入する-1-度だけ) | マシンごとに 1 度 | dnf + EPEL と Homebrew で外部コマンド・Neovim・ibus-anthy・フォントを入れ、この設定を clone して初回起動する |
| [Windows 11 に導入する](docs/setup.md#windows-11-に導入する-1-度だけ) | マシンごとに 1 度 | scoop で外部コマンド・Neovim・zenhan を入れ、この設定を clone して初回起動する |
| [ほかのマシンの変更を取り込む](docs/setup.md#ほかのマシンの変更を取り込む-繰り返し) | 繰り返し | `git pull` と `:Lazy restore` で、設定とプラグインの版を揃える |
| [カーソル色を tmux で効かせる (任意)](docs/setup.md#カーソル色を-tmux-で効かせる-任意) | 任意、1 度だけ | tmux の `terminal-overrides` に 1 行足す |
| [GitLab プレビューのトークンを設定する (任意)](docs/setup.md#gitlab-プレビューのトークンを設定する-任意) | 任意、1 度だけ | GitLab のアクセストークン (と、gitlab.com 以外なら GitLab の URL) を環境変数にする |
| [SSH 越しのヤンクを手元のクリップボードに送る (任意)](docs/setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意) | 任意、1 度だけ | 手元の WezTerm から ssh した先の Neovim で、ヤンクが手元のクリップボードに入ることを確かめる |
| [更新](docs/setup.md#更新) | 更新のたび | Neovim・外部コマンド・プラグインを上げる |
| [ロールバック](docs/setup.md#ロールバック) | 戻すとき | この設定とプラグインを消し、退避した設定と入力ソースを戻す |

## 主なカスタマイズ

### 日本語入力・検索

OS の IME (Linux: ibus/anthy、Windows: zenhan) を Neovim のモードに追従させる。
実装は `lua/config/ime.lua`。

- **挿入モードを抜けると自動で英数に戻る** — `dd` や `:` が IME に食われない。
  切り替えは D-Bus 直叩き (`busctl`) で 1 回 7ms 程度なので、`<Esc>` 直後に
  打ち始めても取りこぼさない。
- **バッファ単位で状態を復元 (sticky)** — 日本語を打っていたバッファで `i` を押すと
  自動で日本語に戻る。コードのバッファは英数のまま。
- **`<C-j>` でトグル** (挿入モード / コマンドライン)。ノーマルモードの `<C-j>` は
  LazyVim のウィンドウ移動のまま。OS のホットキー (Super+Space) も併用できる。
  ピッカー (Space 2 回など) の入力欄では、`<C-j>` は候補の移動 (snacks の既定) になる。
- **lualine に `あ` / `A` を表示** — 状態は ibus の `GlobalEngineChanged` シグナルを
  `gdbus monitor` で購読して把握するため、OS 側で切り替えても表示がズレない
  (ポーリングはしない)。
- **切り替えた瞬間はカーソルのすぐ下にも `あ` / `A` を出す** — lualine は画面の端にあり、
  打っている間の視線から遠いため。`<C-j>`・Super+Space のほか、日本語のまま抜けたバッファで
  挿入モードに入ったときの自動復帰でも出る。約 1 秒か、次の入力・モードの離脱で消える。
  出すのは挿入・置換・端末モードと検索 (`/` `?`) で状態が変わったときだけで (検索では検索欄の
  カーソルのすぐ上)、`<Esc>` で英数に戻るときや `:` では出さない。端末のフォーカスが外れている間も
  出さず、外れている間に変わっていたらフォーカスが戻ったときに出す (GNOME の Super+Space は切り替えの間
  キーボードを掴むので、WezTerm などにはフォーカスの出入りを挟んで届く)。実装は `lua/config/ime_indicator.lua`
  (表示時間は `DURATION_MS`、不要なら `lua/config/ime.lua` の `indicator = false`。次の項の表示も消える)。
- **検索している間は検索欄の右端に `あ` / `A` を出し続ける** — 検索 (`/` `?`) の間は lualine が見えない。
  noice を使うと Neovim が `cmdheight` を 0 にするので lualine が画面の最下段に来て、同じ最下段に出る
  noice の検索欄に覆われるため。その代わりとして、検索欄の右端に日本語は橙の `あ`、英数は青の `A` を
  出し、`<C-j>` や検索の sticky で切り替わるとその場で書き換える。カーソルの色も挿入モードと同じく
  日本語で橙になる (下記の補足)。noice を無効にしている場合は出さない (検索欄も lualine を覆わない)。
- **コマンドラインは英数で始まる** — `:` は常に英数。`/` `?` も英数で始まり、日本語は
  ローマ字のまま下記の Migemo で探せる。`<C-j>` で日本語を直接打つこともでき、
  **検索もバッファ単位で sticky** (日本語のまま検索を抜けたバッファでは、次の `/` `?` も
  日本語で始まる。`<C-j>` で英数に戻してから抜ければ次回から英数)。`*` `#` のように
  マッピングが内部で打つ検索では切り替えない。
  `<C-j>` で日本語にしても、抜けてノーマルモードなどに戻る時は英数に戻す。
  挿入モード中の `<C-r>=` のようにコマンドラインから挿入モードへ戻る経路では、
  コマンドラインに入る前の入力状態に復元する。
- **端末モード・`<C-c>`・置換モードも同じ扱い** — lazygit のコミットメッセージなどを
  端末で書いて `<C-\><C-n>` で抜けた時も英数に戻る。`<C-c>` で挿入モードを抜けた場合も同様
  (`InsertLeave` は `<C-c>` で発火しないため、モード遷移そのものを見ている)。
  一時ノーマルコマンド (`<C-o>`) では切り替えない (`<C-o>:w` のようにコマンドラインを挟んで
  英数に落ちた場合も、挿入モードに戻れば元の状態に戻る)。挿入モードのまま画面が大きく動くとき
  (`<C-End>` など。snacks のスムーズスクロールはアニメーションの 1 コマごとに `:normal!` を実行する)
  も切り替えない。
- **終了時は nvim を起動する前の状態に戻す** — gnome-shell は外部からの engine 変更を
  観測しないため、nvim が強制した英数のまま抜けると gnome-shell の内部状態がズレたままになり、
  Super+Space での入力ソース切替が噛み合わなくなる。セッション中に Super+Space で
  切り替えた場合はその値を追随して戻す。`Ctrl+Z` での中断時も同様。
- IME デーモンが居ない環境・headless・対応コマンドが無い Windows では、
  何もせず静かに無効化される (エラーは出ない)。

Linux では **GNOME の入力ソース登録と anthy のショートカット調整が必要**。
手順は [docs/setup.md の AlmaLinux 導入の手順 13〜15](docs/setup.md#almalinux-10-に導入する-1-度だけ)
にある (この 2 つをやらないと `<C-j>` が anthy に食われる)。設定は `/usr/bin/gsettings` で書くこと
(Homebrew の glib が入っていると、PATH の先頭の `gsettings` は GNOME の設定に書かないので効かない)。
日本語が一切入力できなくなった場合の切り分けは
[注意点](docs/setup.md#注意点)を参照。

#### 補足

- **Neovim の中では `<C-j>` を使うこと**: gnome-shell は ibus の global engine が外部から
  変わっても自分の内部状態を更新しない (gsettings の `current` を書いても追従しない)。
  そのため nvim がモードに応じてエンジンを切り替えた後に Super+Space を
  押すと、gnome-shell は古い認識を基準に「次のソース」を選ぶので、一手ぶん空振りすることがある
  (もう一度押せば揃う)。`<C-j>` は nvim が直接切り替えるので常に意図どおり動く。
  なお nvim を抜けた時点では上記の復帰処理で必ず整合が取れるため、OS 側の切替が
  壊れたままになることはない。
  GNOME 49 では、[docs/setup.md の上部バーの節](docs/setup.md#gnome-の上部バーを-ime-連携に合わせる-任意)で
  GNOME Shell の拡張 (`gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com`) を入れると、上部バーと
  Super+Space の順番が nvim の切り替えに付いてくるので、このずれは起きない。
- **変換中の `<Esc>` は 2 回**: 1 回目は anthy が変換のキャンセルに使うため、
  Neovim には届かない。これは IME 側の仕様。
- **カーソル色**: 挿入モードとコマンドライン (検索中を含む) のカーソル色も IME 状態で変わるが、
  `tmux-256color` には `Cs`/`Cr` が無く Neovim が OSC 12 を出さないため、tmux 越しでは既定で効かない。
  使いたい場合の設定は
  [docs/setup.md の任意設定](docs/setup.md#カーソル色を-tmux-で効かせる-任意)にある。
- **Windows**: `zenhan.exe` (推奨) か `im-select.exe` が PATH にあれば、モード連動と
  終了時の復帰は同じように動く。ただし ibus の `GlobalEngineChanged` に相当する通知が
  無いため、**OS 側で IME を切り替えても Neovim は気付けない** (あ/A 表示が実態と
  ズレることがあり、カーソル直下の表示も出ない)。どちらのコマンドも無ければ何もしない。
- **Neovide では未確定文字列をカーソル位置に表示する** — Neovide は既定では IME の未確定文字列
  (変換前の読みや変換中の候補) を一切描かず、確定するまで何も出ない。`lua/config/ime_preedit.lua` が
  Neovide の `preedit_handler` を差し替え、カーソル位置に下線付きで描く (行の続きは右へ押し出され、
  変換中の文節は反転)。バッファ自体は確定まで変わらないので、undo・LSP・補完には影響しない。
  Neovide 0.16 以上と Neovim 0.12 以上が必要。コマンドライン (`/` `?` `:` など) でも、noice が描く
  コマンドラインのカーソル位置に同じように出す (noice を無効にしている場合は出ない)。
  端末モードでは従来どおり表示されない。
  端末 (Windows Terminal / WezTerm) では未確定文字列を端末が描くので、この処理は関係しない。
- **既知の制限 — nvim を同時に 2 つ以上起動した場合**: 起動時の英数化を、もう一方の
  nvim が「gnome-shell による切り替え」と誤認し、終了時の復帰先を英数で上書きすることがある。
  外部からの変更が「gnome-shell によるものか別の nvim によるものか」を判別する手段が
  無いため、現状は許容している (その場合も Super+Space をもう一度押せば揃う)。
- **Migemo ([luamigemo](https://github.com/delphinus/luamigemo))** — ローマ字のまま日本語を
  検索 (`/kensaku<CR>` が「検索」「けんさく」「ケンサク」等にマッチ)。純 Lua で辞書同梱のため
  Deno もネットワークも不要。`/` `?` の `<CR>` に加え、flash.nvim の `s` (ラベルジャンプ) と
  snacks picker の grep (`<leader>sg` `<leader>/` など) でも同じ変換が効く。入力がローマ字として
  読めるときだけ変換するので、英単語や正規表現の検索はそのまま通る。
  検索のたびに IME を入れ直さずに済むので、この構成では要になる。実装は `lua/config/migemo.lua`。
- **flash の `s` で日本語へ飛ぶ** — `s` → ローマ字 → `;` → ラベル (Enter なら一番近い一致へ)。
  `;` を打つまではラベルで飛ばないので、ローマ字を打ち足す途中でラベルの文字に当たっても誤って
  飛ばない (英単語へ飛ぶときも `;` が要る)。打ちかけのローマ字 (`nihon` の途中の `nih`) でも
  予測で一致を出し続ける。1 文字目や `shi` `ka` のように候補の多い音節は、まずかなだけで探して
  軽くしている (画面にかなが無ければ辞書を引く。漢字は次の 1 文字で出る)。一度一致が出た後は、
  一致が無くなる文字を打っても直前の一致を保つ (同梱辞書には送り仮名まで含む語が少なく、
  `atarashii` と読みを最後まで打つと「新しい」に当たらないため。`atarashi` の「新し」で止まる)。
- **Migemo の一致から選んで検索** — `/kensaku` の後に `<Tab>` で、バッファ内で Migemo に一致した
  文字列 (「検索」「けんさく」など) を出現回数の多い順に補完候補として出す (blink.cmp)。
  選ぶとローマ字がその文字列に置き換わり、`<CR>` でその文字列そのものを検索するので、
  Migemo の正規表現より絞り込める。探す文字列は必ずバッファにあるので、IME も変換も要らない。
  3 文字以上のローマ字で効く。照合は ripgrep に任せている (Vim の正規表現では Migemo の巨大な
  パターンが数千行で数百 ms 以上かかるため)。実装は `lua/config/migemo_blink.lua`。
- **`*` `#` の日本語対応** — 非 ASCII の単語は `\<` `\>` を付けずに検索する (日本語では
  単語境界が文字種の切り替わりにしか成立せず、「日本語検索」の中の「検索」に当たらないため)。
  visual 選択して `*` `#` で選択文字列をそのまま検索できる。
- 全角スペース (U+3000) を波線で可視化、全角括弧の `%` ジャンプ対応、
  日本語向け `formatoptions` (mM)、CJK スペルチェック、
  `fileencodings` (cp932/euc-jp 自動判別) など。

### Markdown / GLFM 執筆

- LazyVim extra `lang.markdown` を有効化し、以下を上書き:
  - 整形連鎖から **prettier を除外** (GLFM の数式・脚注・`[[_TOC_]]` を壊すため)。
    整形は markdownlint-cli2 `--fix` のみ。Markdown / MDX の待ち時間の上限は 10 秒
    (速い環境では処理が終わった時点で戻る)。ほかのファイルは LazyVim 既定の 3 秒。
  - **markdown-toc を外した** (npm の最終リリースが 2017 年で、更新が止まっている)。目次は GitLab が
    `[[_TOC_]]` から描画のたびに作る。ファイルに書き込む目次が要るときは、marksman のコードアクション
    (`<leader>ca` → Table of Contents。見出しの ID は GitLab の方式) で作る。
  - **markdown-preview.nvim を外した** (2023-10 から更新が止まっており、GLFM 固有の記法を描けない。
    Windows では build も通らなかった)。代わりに下の GitLab プレビューを使う。
  - render-markdown.nvim は無効化 (記法をそのまま見て書き、見た目はプレビューで確かめる)。
  - 除外したい markdownlint ルールは `lua/plugins/lang-markdown.lua` の `disabled_rules` に列挙。
- **GitLab プレビュー** (`<leader>cp` で切り替え、`:GitLabPreview` / `:GitLabPreviewStop`) — 編集中の内容を
  GitLab の Markdown API に描かせて、ブラウザに出す。GitLab が描いた HTML をそのまま使うので、
  `[[_TOC_]]`・`` $`…`$ ``・`>>>`・`{+ +}`・`[~]`・アラート・`#123` などの参照も GitLab と同じに見える。
  - 打つたびに (約 0.3 秒ごと。保存しなくてよい) 描き直し、スクロールがカーソルの位置に付いてくる。
    表示している markdown のバッファに追従する (別のファイルに移ると、ページもそちらになる)
  - **内容を GitLab に送るのは、環境変数 `GITLAB_TOKEN` (`read_api` のアクセストークン) があるときだけ**。
    送り先は `GITLAB_HOST` (無ければ gitlab.com) だけで、git の remote のホスト名からは決めない。
    設定の手順は [GitLab プレビューのトークンを設定する](docs/setup.md#gitlab-プレビューのトークンを設定する-任意)
  - git の remote (origin) のホストが送り先と同じなら、そのプロジェクトとして描かせる (`#123` などがリンクになる)。
    違うとき、そのプロジェクトを読めないときは、プロジェクト無しで描かせる
  - 画像と動画の相対リンクは手元のファイルを出す (push していない画像も見える)。ほかのファイルへの
    リンクは GitLab の URL のまま (新しいタブで開く)
  - トークンが無い・GitLab に届かないときは、markdown-it で描いた**近似表示**になり、理由をバナーに出す。
    近似表示では inline diff・色見本・`>>>`・include・参照・絵文字の短縮記法・PlantUML は描かない。
    描画用のライブラリ (cdn.jsdelivr.net) にも届かないときは、原文をそのまま出す
  - 数式 (KaTeX) と図 (mermaid) は、GitLab と同じくブラウザが描く (ライブラリの版は GitLab とは違う)
  - 安全策: 127.0.0.1 だけで待ち受け、URL に推測できない値を入れる。返すファイルはリポジトリの中だけで、
    `.git` は返さない。トークンはコマンドラインにもファイルにも書かない
  - 制限: 非公開のプロジェクトの `/uploads/` の画像は出ないことがある (ブラウザが GitLab のログインの Cookie を
    送らないため)。`::include` は GitLab が既定のブランチの内容で展開する (手元の未 push の変更は入らない)
  - ブラウザは OS の既定。変えるときは `vim.g.gitlab_preview_browser` に関数を入れる
    (例: Edge の別窓なら `function(url) vim.system({ "cmd.exe", "/d", "/c", "start", "", "msedge", "--app=" .. url }) end`)
  - 実装は `lua/config/gitlab_preview/` (配線は `lua/plugins/gitlab-preview.lua`)
- **画像の貼り付け** ([img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim)、`<leader>ci`) — クリップボードの
  画像 (スクリーンショットなど) を、.md と同じディレクトリの `assets/` に保存し、`![](assets/….png)` を入れる。
  ファイル名を聞かれる (空のまま Enter で日時)。取り出しは Windows が PowerShell、Linux が wl-clipboard。
  リポジトリに置かれた `.img-clip.lua` は読み込まない (貼り付けただけで、その Lua が走らないように)
- **GLFM のスニペット** (`snippets/markdown.json`) — `gl` で始まる名前で補完に出る:
  `gltoc` (`[[_TOC_]]`)・`glnote` / `gltip` / `glimportant` / `glwarning` / `glcaution` (アラート)・`gldetails` (折りたたみ)・
  `glmath` / `glimath` (数式)・`glmermaid`・`glplantuml`・`glquote` (`>>>`)・`gladd` / `gldel` (`{+ +}` / `{- -}`)・
  `glna` (`- [~]`)・`glfn` / `glfndef` (脚注)・`glfront` (front matter)・`glinclude`・`glcolor` (色見本)・`gldl` (定義リスト)。
  `gldetails` はインライン HTML なので、markdownlint の MD033 に当たる
- **記法の記号を隠さない** — LazyVim 既定の `conceallevel=2` では、コードフェンスの行・
  インラインコードの `` ` ``・強調の `*` `_`・リンクの URL などがカーソル行以外で隠れる。
  記法をそのまま見て書けるよう、markdown バッファでは常に表示する (`lua/config/autocmds.lua`)。
  一時的に隠し表示へ戻すには `<leader>uc`。
- **[vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)** — パイプ表の整形
  (全角幅対応)。markdown バッファ限定で `<leader>tm` (toggle) / `<leader>tr` (realign)。

### その他

- 有効化済み extras: `lang.markdown` / `lang.json` / `lang.yaml` / `lang.toml` /
  `editor.dial` / `ui.treesitter-context` / `lang.git` / `util.dot`
  (`lua/config/lazy.lua` で import。`lazyvim.json` は gitignore のため import 方式で管理)
- Windows では shell を PowerShell (pwsh 優先、UTF-8 入出力) に設定
- Windows では、`<leader>gg` で開いた lazygit の `e` が、lazygit の窓の中に入れ子の Neovim を開く (`:q` で lazygit に戻る)。
  snacks.nvim の既定の `nvim-remote` (この Neovim でファイルを開き、lazygit を閉じる) は POSIX sh の構文のコマンドで、
  Windows の lazygit は cmd.exe で実行するので動かないため。Linux は `nvim-remote` のまま。どちらの OS でも
  `editInTerminal` を明示し、自分用の lazygit の `config.yml` の値に左右されないようにしている (`lua/plugins/lazygit.lua`)。
  入れ子の Neovim で `<Esc>` を 0.2 秒以内に 2 回押すと、外側の Neovim が端末モードを抜ける (snacks の端末の既定)。
  `i` で lazygit の窓に戻る。Windows の実機ではまだ確かめていない ([記録](docs/verification/readme.md#付録-windows-の-lazygit-の-e-の設定を-linux-で確かめた記録-2026-10-08))
- **SSH 越しでは、ヤンク・削除を手元のクリップボードに送る** — ssh したシェル (`SSH_CONNECTION` がある) で起動すると、
  `y` `d` などでレジスタに入れたものを OSC 52 で手元の端末に渡し、手元のクリップボードに入れる (ローカルと同じく
  `clipboard=unnamedplus`)。手元にもサーバーにも足すソフトは無いが、端末が OSC 52 の書き込みに対応している必要がある
  (WezTerm の nightly など。GNOME Terminal と Ptyxis は非対応)。向きは Neovim → 手元だけで、`p` は端末に問い合わせず
  この Neovim が最後に送った内容を貼る (OSC 52 の読み出しは WezTerm も Windows Terminal も応えず、10 秒待たされるため)。
  手元でコピーしたものは端末の貼り付けで入れる。LazyVim 既定のままでは SSH の中の `clipboard` が空で `y` が
  入らず (Neovim は `clipboard` が空のときしか OSC 52 を自動で選ばない)、`"+p` も 10 秒待つので、
  `lua/config/options.lua` で明示している。手順は
  [docs/setup.md の SSH の節](docs/setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)

## 外部依存

Neovim 0.12 以上のほかに、git / ripgrep / fd / C コンパイラ / curl・tar・gzip・unzip /
Node.js / Nerd Font / ibus + ibus-anthy (Linux) を前提にしている
(`lazy-lock.json` の nvim-treesitter が Neovim 0.12 を要る。LazyVim 自身の下限は 0.11.2)。
**足りなくてもエラーにならず静かに壊れる**ため、初回起動の前に揃えること。
GitLab プレビューには GitLab のアクセストークン・curl 8.3 以上・ブラウザが、Linux での画像の貼り付けには
wl-clipboard が要る (どれも任意。無ければその機能だけが使えない)。

用途と必須かどうかの一覧、導入手順は
[docs/setup.md](docs/setup.md#必要なもの一覧)にまとめてある。

## lazy-lock.json の運用

プラグインのバージョン再現のため `lazy-lock.json` を git で追跡する。
`:Lazy update` 後に変化した lock ファイルをコミットすること
(別マシンでは `:Lazy restore` で同じバージョンに揃う)。
`:Lazy sync` は update を含むので、揃えるだけのときは使わない。
初めてのマシンでは初回の導入が lock ファイルを書き換えるので、
[docs/setup.md の AlmaLinux 導入の手順 16](docs/setup.md#almalinux-10-に導入する-1-度だけ) の形で揃える。
