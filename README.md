# 💤 LazyVim 設定 (日本語編集 + Markdown 執筆向け)

[LazyVim](https://github.com/LazyVim/LazyVim) をベースに、日本語の入力・検索と
Markdown (GLFM) 執筆を強化した Neovim 設定。

**新しいマシンで動かすまでの手順は [docs/setup.md](docs/setup.md)** にある
(外部コマンドの導入、GNOME + ibus の初期設定、初回起動と動作確認まで)。
この README は「何ができる設定か」を説明する。

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
- **lualine に `あ` / `A` を表示** — 状態は ibus の `GlobalEngineChanged` シグナルを
  `gdbus monitor` で購読して把握するため、OS 側で切り替えても表示がズレない
  (ポーリングはしない)。
- コマンドライン (`:` `/`) は常に英数。日本語検索は下記の Migemo が担う。
  挿入モード中の `<C-r>=` のようにコマンドラインから挿入モードへ戻る経路では、
  元の入力状態に復元する。
- **端末モード・`<C-c>`・置換モードも同じ扱い** — lazygit のコミットメッセージなどを
  端末で書いて `<C-\><C-n>` で抜けた時も英数に戻る。`<C-c>` で挿入モードを抜けた場合も同様
  (`InsertLeave` は `<C-c>` で発火しないため、モード遷移そのものを見ている)。
  一時ノーマルコマンド (`<C-o>`) では切り替えない。
- **終了時は nvim を起動する前の状態に戻す** — gnome-shell は外部からの engine 変更を
  観測しないため、nvim が強制した英数のまま抜けると gnome-shell の内部状態がズレたままになり、
  Super+Space での入力ソース切替が噛み合わなくなる。セッション中に Super+Space で
  切り替えた場合はその値を追随して戻す。`Ctrl+Z` での中断時も同様。
- IME デーモンが居ない環境・headless・対応コマンドが無い Windows では、
  何もせず静かに無効化される (エラーは出ない)。

Linux では **GNOME の入力ソース登録と anthy のショートカット調整が必要**。
手順は [docs/setup.md の「日本語入力 (IME) を用意する」](docs/setup.md#4-日本語入力-ime-を用意する)
にある (この 2 つをやらないと `<C-j>` が anthy に食われる)。
日本語が一切入力できなくなった場合の切り分けは
[つまずきやすい点](docs/setup.md#つまずきやすい点)を参照。

#### 補足

- **Neovim の中では `<C-j>` を使うこと**: gnome-shell は ibus の global engine が外部から
  変わっても自分の内部状態を更新しない (gsettings の `current` を書いても追従しないことを
  実測で確認済み)。そのため nvim がモードに応じてエンジンを切り替えた後に Super+Space を
  押すと、gnome-shell は古い認識を基準に「次のソース」を選ぶので、一手ぶん空振りすることがある
  (もう一度押せば揃う)。`<C-j>` は nvim が直接切り替えるので常に意図どおり動く。
  なお nvim を抜けた時点では上記の復帰処理で必ず整合が取れるため、OS 側の切替が
  壊れたままになることはない。
- **変換中の `<Esc>` は 2 回**: 1 回目は anthy が変換のキャンセルに使うため、
  Neovim には届かない。これは IME 側の仕様。
- **カーソル色**: 挿入モードのカーソル色も IME 状態で変わるが、`tmux-256color` には
  `Cs`/`Cr` が無く Neovim が OSC 12 を出さないため、tmux 越しでは既定で効かない。
  使いたい場合の設定は
  [docs/setup.md の任意設定](docs/setup.md#カーソル色を-tmux-で効かせる-任意)にある。
- **Windows**: `zenhan.exe` (推奨) か `im-select.exe` が PATH にあれば、モード連動と
  終了時の復帰は同じように動く。ただし ibus の `GlobalEngineChanged` に相当する通知が
  無いため、**OS 側で IME を切り替えても Neovim は気付けない** (あ/A 表示が実態と
  ズレることがある)。どちらのコマンドも無ければ何もしない。
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
- **`*` `#` の日本語対応** — 非 ASCII の単語は `\<` `\>` を付けずに検索する (日本語では
  単語境界が文字種の切り替わりにしか成立せず、「日本語検索」の中の「検索」に当たらないため)。
  visual 選択して `*` `#` で選択文字列をそのまま検索できる。
- 全角スペース (U+3000) を波線で可視化、全角括弧の `%` ジャンプ対応、
  日本語向け `formatoptions` (mM)、CJK スペルチェック、
  `fileencodings` (cp932/euc-jp 自動判別) など。

### Markdown / GLFM 執筆

- LazyVim extra `lang.markdown` を有効化し、以下を上書き:
  - 整形連鎖から **prettier を除外** (GLFM の数式・脚注・`[[_TOC_]]` を壊すため)。
    整形は markdownlint-cli2 `--fix` + markdown-toc のみ。
  - render-markdown.nvim は無効化 (プレビューは markdown-preview.nvim を使用)。
  - 除外したい markdownlint ルールは `lua/plugins/lang-markdown.lua` の `disabled_rules` に列挙。
- **[vim-table-mode](https://github.com/dhruvasagar/vim-table-mode)** — パイプ表の整形
  (全角幅対応)。markdown バッファ限定で `<leader>tm` (toggle) / `<leader>tr` (realign)。

### その他

- 有効化済み extras: `lang.markdown` / `lang.json` / `lang.yaml` / `lang.toml` /
  `editor.dial` / `ui.treesitter-context` / `lang.git` / `util.dot`
  (`lua/config/lazy.lua` で import。`lazyvim.json` は gitignore のため import 方式で管理)
- Windows では shell を PowerShell (pwsh 優先、UTF-8 入出力) に設定

## 外部依存

Neovim 0.11.2 以上のほかに、git / ripgrep / fd / C コンパイラ / curl・tar・gzip・unzip /
Node.js / Nerd Font / ibus + ibus-anthy (Linux) を前提にしている。
**足りなくてもエラーにならず静かに壊れる**ため、初回起動の前に揃えること。

用途と必須かどうかの一覧、導入手順は
[docs/setup.md](docs/setup.md#必要なもの一覧)にまとめてある。

## lazy-lock.json の運用

プラグインのバージョン再現のため `lazy-lock.json` を git で追跡する。
`:Lazy update` 後に変化した lock ファイルをコミットすること
(別マシンでは `:Lazy restore` で同じバージョンに揃う)。
