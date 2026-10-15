# 設定の仕組み (IME 連携・日本語の検索・Markdown / GLFM)

[AGENTS.md](../../AGENTS.md) を Codex が読める大きさ (32 KiB) に収めるため、アーキテクチャはここに置く。下のファイルを変える前に読む。

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
  setup-notes の neovim.md の「LazyVim の IME 連携に GNOME の上部バーを合わせる」で入れる。Neovim の設定ではない)。GNOME Shell は ibus の engine が外から変わっても
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
  通常の修正は、構文木全体の構造を保つ厳しい検査と、説明リストなどの従来の検査の 2 段で確かめる。
  強制改行や語の中の強調の消失・リストの結合・開始番号の変更・段落の項目への出入りは認めない。
  厳しい検査の文字は、HTML で同じに見える ASCII の空白の並びだけを畳む (全角空白は比べる)。
  変えてよい差が決まっている書き換え (MD026 の見出しの句読点・MD039 のリンクの端の空白・MD044 の大文字小文字・
  MD051 の断片の大文字小文字) は、その差だけを両方の木から消してから比べる (表記の修正と同じまとめで確かめ、
  確かめる回数を増やさない)。
  構造を作る書き換え (MD018・MD020・MD037・MD011 とカスタムルール) は従来の検査だけで当て、
  その結果で厳しい検査の基準を取り直す。従来の検査 (説明リスト・リテラル・GitLab の記法) は最初の文書と比べ続ける。
  GitLab の参照 (`#123`・`!123`・`~label` など)・`[[_TOC_]]` と wiki のリンク・`::include` の行頭・画像の `{width=…}` の
  原文を変える修正は当てない。`#数字` と既にある見出しの行は、見出しへの変換を有効にしても直さない。箇条書きの記号 (MD004) と
  番号 (MD029) は、リストごとにまとめて当てるか見送る (1 項目めの番号だけ見送ると `3. 2. 3.` が残る)。番号の長さが変わる
  まとめは複数の行を書き換えるので、同じ行のほかの修正は次の回に回す (列がずれて修正の範囲が不正になるため)。
  分類の表に無い組み込みルール (markdownlint を上げて増えたもの) の修正は、表に足すまで当てない。
  修正候補はまとめて当てて 1 回で検査し、構造が変わるときだけ半分に分けて原因を除く (修正ごとに
  文書全体を解析すると、違反の多い長い文書で保存の上限を超えるため)。markdownlint の設定は、
  Neovim の作業ディレクトリを基準に探す (ファイルが
  その下にあるとき。上の階層のプロジェクト設定も効く)。
  固定した npm 依存は `stdpath("data")/glfm-format` に `:GlfmFormatInstall` で導入する。
  保存時に依存を自動取得しない。Node.js 22 以上が必要。conform の
  `formatters_by_ft` は `opts` 関数で明示代入して置き換え、`markdown.mdx` の連鎖も全部書いている。
  Markdown / MDX だけ `timeout_ms=10000` (他は既定の 3000)。新規 AlmaLinux VM では
  単独整形が 3.01 秒で既定 timeout に掛かったため。名前付き timeout を持つ表はリストではなく
  deep-merge されるので、表の `opts` に戻すと extra の prettier 等が残る。
  実 UI の保存と GLFM 数式・目次の保持、連鎖・既定値を確認した (docs/verification/setup.md の新規 VM 記録)。
- **HTML のブロックの整形** (分類 `html`、既定で有効) は、markdownlint の修正が終わった文書に最後に 1 回当てる
  (`formatHtmlBlocks`)。lint の段は HTML の中を保護範囲として変えないので、整形した HTML を崩さない。lint の修正で
  できた HTML のブロックも同じ保存で整形するので、2 回目の保存で変わらない。
  - 対象は Comrak の `HtmlBlock` のうち一般のタグで始まるもの (CommonMark の種類 6・7) だけ。`pre`・`script`・`style`・
    `textarea` で始まるもの (種類 1)・コメント (種類 2。markdownlint の指示に使う) と、段落の中のインライン HTML は変えない
  - 整形器は js-beautify (lock で固定)。字下げ 2・折り返さない・空行を足さない・テンプレートの記法を解釈しない。
    `pre`・`textarea`・`script`・`style`・`code`・`kbd`・`samp` の中身は変えない。閉じていない断片 (`<details>` だけの
    ブロックなど) に閉じタグを足さず、閉じタグだけの断片も深さ 0 で出すので、Markdown をはさむ HTML を断片ごとに
    整形できる。prettier は 80 桁で折り返し、閉じていない断片に閉じタグを足そうとするので使わない
  - Markdown をはさんだ断片 (`<details>` と `</details>` の間に本文があるもの、`<td>` の中に Markdown を書いた表など) は、
    断片ごとに入れ物の字下げから始め、前の断片の深さを持ち越さない。HTML のブロックの 1 行目を 4 つ以上字下げすると、
    空行の後ではコードブロックになり描画が崩れるため。閉じの断片 (`</td>`・`</tr>`・`</table>`) は行頭に並ぶ
  - 入れ物 (リスト・引用・説明・脚注) の中のブロックは、各行が「入れ物の接頭辞 + literal の行」のときだけ扱う。2 行目からは
    元の 2 行目の接頭辞、1 行だったブロックは 1 行目の接頭辞の `>` 以外を空白にしたものを付ける
  - 当てる前に、空の行を作る整形を外す (ブロックが終わり、後ろの行が Markdown になる)。当てた後は、Comrak の HTML の描画を
    比べる正規化 (`normalizedHtml`。空白がそのまま出る要素の中は原文、ほかは空白を畳み、ブロック要素・表の要素・`<br>` に
    接する空白は比べない。インライン要素の間の空白は有無を比べる)・HtmlBlock の中身だけを正規化した構文木の全体・
    GitLab の記法の並び・front matter・整形したブロックの literal (2 回目で変わらないこと) がすべて同じことを確かめる。
    まとめて当てて 1 回で確かめ、落ちたら半分に分けて原因のブロックを外す。脚注の定義の行に続けて書いた 1 行の HTML は、
    続きの行の字下げ (4) が 1 行目の接頭辞の幅と違い、literal の確かめで外れるので変えない
  - js-beautify は整形するブロックがあるときだけ読む。読めないときは `:GlfmFormatInstall` を促すエラーで止める
    (HTML のブロックの無い文書は、依存を入れ直す前でも今までどおり整形する)
  - 試験は `tools/glfm-format/test/html.test.mjs` (表・入れ子・セルの中の Markdown・入れ物の中・描画の比較・壊す整形の拒否)
- 整形器は、出力を変えない近道で速くしている。長い文書の時間の大半は、Comrak の解析の回数 (15,092 行で 1 回 126 ms) と、
  その結果をたどる JavaScript だった。
  - 同じ文字列の解析の結果と検査の値は、1 回の呼び出しの中で使い回す (projection・候補の検査・終わりの確かめ)。
    型・同じ型の兄弟の数・部分木の正規化も、解析の結果ごとに 1 回だけ求める
  - まとめの修正は、改行が 1 種類の文書なら行の分け直し 1 回で当てる (`applyFixes`。改行が混ざる文書は `applyFix` を順に当てる)
  - コード・数式・HTML の中身や GitLab の記法を必ず変える修正は、全文を解析せずに拒む (`doomedProtectedGroups`)。
    GitLab の記法は正規表現の照合、文書の直下のコードブロックの中の行だけを変える修正 (行を足し引きしないもの) は
    そのブロックの行だけの小さな解析、そのほかのリテラルはいっしょに当てた文書の 1 回の解析で判定する。
    いっしょに当てるのは、修正がすべてリテラルの範囲の中にあり、リテラルを含む段落・見出し・表・ブロックが互いに別のまとめだけ
    (同じ段落の 2 つのコードスパンは、片方の修正がもう片方の範囲を変えうるので、1 つずつ全文の解析で確かめる)。
    判定は今の文書に対して行い、前の修正を受け付けて文書が変わったら、残りを判定し直す。
    整形済みの文書でも毎回出るコードの中の MD038・MD010 の確かめに、全文の解析を使わなくなった
  - 選ばれる修正が無く、説明リストの印 (行頭の `:`・`~`) も無い文書は、解析せずに返す。行頭にタグの無い文書は、
    HTML の段でも解析しない。整形済みの HTML のブロックしか無い文書は、描画しない
  - 試験用の `exhaustive: true` で近道を切った結果と、近道ありの結果が同じことを `test/fast-paths.test.mjs` が確かめる
  - CLI は、Node が対応していれば (22.8 以上) 依存のコンパイルの結果を `stdpath("data")/glfm-format/.compile-cache` に残す
- 短い文書の保存の時間の大半は、node の起動 (約 60 ms) と依存の読み込み (約 160 ms) なので、予備のプロセス
  (`lua/config/glfm_spare.lua` と `tools/glfm-format/spare.mjs`) で保存の外へ出している。
  - Markdown のバッファを開くと、依存を読み込んで標準入力を待つ node を 1 つ起動しておく。保存のときは、
    CLI に渡すはずの引数と cwd を JSON の 1 行で、その後に本文を渡す。予備は `format.mjs` の `cli()` を同じ引数で走らせ、
    stdout・stderr・終了コードは CLI と同じ。1 回使ったら終わり、保存の後に次の予備を起動する
  - 使い回さないのは、同じ node で続けて整形すると、JS の設定やカスタムルールのモジュールと内部の状態が残り、
    CLI と結果が変わるため (状態を持つカスタムルールで実際に変わった)。設定・カスタムルールは要求のときに読むので、
    予備を起動した後の変更も次の保存で効く
  - conform の formatter は、バッファごとに設定を返す関数 (`glfm_format.conform_formatter`)。予備が使えるときは Lua の
    formatter、使えないとき (予備が無い・待つ間に終わった・起動の後に `format.mjs`・`spare.mjs`・依存の lock と主な包みの
    `package.json`・`exepath("node")` とリンクの先の実体・環境変数・依存の場所が変わった) は、今までの CLI の設定をそのまま
    返し、次の保存のために予備を起動し直す。lock を変えない `node_modules` の中の書き換えは見ない。Lua の formatter の結果と
    エラーの文言は、conform の job と同じ規則で作る (行の分け方・末尾の改行・`Formatter '…' error: …`)。cwd も job と同じく
    Neovim のプロセスの cwd (`vim.uv.cwd()`) を渡す
  - 予備が要求を受け付けなかったとき (終了コード 86) と、外からシグナルで止められたときは、残りの時間で CLI を走らせる。
    整形器そのものの失敗ではやり直さない (今と同じく原文のまま保存する)
  - conform は Lua の formatter の子を止めないので、整形の上限 (`lang-markdown.lua` の `format_timeout_ms`) で予備を止め、
    conform と同じ `Formatter '…' timeout` を返す (非同期の整形が終わらないままにならないように)。遅れた結果は当てない
  - Markdown のバッファをすべて閉じたとき・filetype を変えて Markdown のバッファが無くなったとき・`VimLeavePre`・
    `:GlfmFormatInstall` の間は予備を止める。予備を使わないときは `lang-markdown.lua` の `format_spare = false`
  - 見送った案: 常駐 (上の理由)、V8 の起動スナップショット (Node 26.10 は自前のモジュールを読むと作る段階で止まり、
    依存を 1 つにまとめる道具が要る)、markdownlint を直接呼ぶ (減るのは約 40 ms で、設定の探し方の再実装が出力の差になる)、
    保存の後に整形する `format_after_save` (未整形の内容がいったんディスクに書かれ、`:wq` で待たされる)
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
- 整形だけの対象は `format_fixes` で分類名・ルール名 (別名も可) に true / false を指定する。
  診断は残る。ルール名の指定 > 分類の指定 > 既定の順で決め、有効にしても構造検査は外れない。
  分類の表と既定は `format.mjs` だけに持つ。Lua はキーと値の型を確かめ、名前順に
  `--enable-fixes`・`--disable-fixes` に直すだけ。空の表や nil では引数を渡さない。
  未知の名前や有効・無効の重複は Node が終了コード 1・標準出力なしで拒み、conform は原文を保つ。
  MDX の連鎖と nvim-lint には渡さない。ルールごとの例は [GLFM 整形器のルール一覧](../reference/glfm-format.md)、
  代表的な例は README の「整形の例」にあり、`tools/glfm-format/test/reference.test.mjs` がどちらの例もすべて整形し直して確かめる。
- render-markdown.nvim と **markdown-preview.nvim は無効** (後者は 2023-10 から更新が止まり、GLFM を描けない)。
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

