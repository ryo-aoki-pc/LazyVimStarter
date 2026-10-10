# LazyVim 導入の補足資料

操作は [setup.md](../setup.md)、実施結果は [検証記録](../verification/setup.md) を参照する。

## 補足

### EPEL が要る理由

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 2 に対応する。

- `wl-clipboard` は AlmaLinux の BaseOS / AppStream に無く、EPEL にある。EPEL を入れずにこの節の手順 3 を貼ると `Unable to find a match: wl-clipboard` で止まる
- `ripgrep` と `fd-find` も EPEL にあるが、この設定では Homebrew の `ripgrep` と `fd` を入れる (この節の手順 10。[Homebrew を使う理由と導入先](#homebrew-を使う理由と導入先))
- `epel-release` は AlmaLinux の `extras` リポジトリにあり、追加のリポジトリ設定は要らない。弱い依存として `dnf-plugins-core` も入る

### dnf で入れるもの

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 3 に対応する。

- **`unzip` は必須**: Mason は zip で配布されるツール (`stylua` など) の展開に使う。無いと**そのツールだけ**が静かに入らず、ほかは入るので気付きにくい
- **`gcc`**: nvim-treesitter は各言語のパーサーを手元で C としてコンパイルする。C コンパイラが無いとハイライトが効かない
- **`nodejs` / `nodejs-npm`**: Mason が `markdownlint-cli2` / `bash-language-server` / `json-lsp` / `yaml-language-server` を npm パッケージとして入れる。**node を消すと Markdown の lint と整形が丸ごと止まる**
- `npm` と書いても `nodejs-npm` に解決されて入るが、この節の手順 4 の `rpm -q` はパッケージ名でしか引けないので、両方の手順で `nodejs-npm` と書いている
- **`file` / `procps-ng`**: Homebrew の前提 (この節の手順 8)。GNOME の PC には入っていることが多い
- **`ibus-anthy`**: AlmaLinux 10 の Workstation には最初から入っている。入っていれば dnf は `already installed` と出して飛ばす。依存として `ibus-anthy-python` と `anthy-unicode` が入る
- **Deno は要らない**: 日本語のローマ字検索 (Migemo) は純 Lua の luamigemo が辞書ごと同梱している
- **`wl-clipboard`**: `<leader>ci` (img-clip.nvim) がクリップボードの画像を `wl-paste` で取り出す。EPEL にある。無くても `<leader>ci` が使えないだけ

### 退避するもの

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 5 に対応する。

- `~/.config/nvim` は設定、`~/.local/share/nvim` はプラグインと Mason のツール、`~/.local/state/nvim` は undo・shada・ログ、`~/.cache/nvim` はキャッシュ
- Neovim を入れる前
- Neovim が初めてのマシンでは何も起きない

### clone 先

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 6 に対応する。

- **このリポジトリが Neovim の設定ディレクトリそのもの**なので、clone 先は `~/.config/nvim` にする。Neovim は `$XDG_CONFIG_HOME/nvim` (未設定なら `~/.config/nvim`) しか読まない
- 別の場所に置くなら `NVIM_APPNAME` か `XDG_CONFIG_HOME` を設定する (本書では扱わない)
- clone 元は HTTPS の URL にしてある。公開リポジトリなので鍵は要らない。`git@github.com:` の形は、SSH 鍵を GitHub に登録していない新しいマシンでは `Host key verification failed` で失敗する
- `main` ブランチは LazyVim starter の上流の写しで、この設定は入っていない

### Homebrew を使う理由と導入先

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 8 に対応する。

- Neovim を Homebrew で入れるため (EPEL の Neovim は古い。[選択した方針](#選択した方針))
- ripgrep と fd も Homebrew で入れる。yazi などのほかのツールも Homebrew の `fd` / `ripgrep` を入れるので、EPEL の `fd-find` / `ripgrep` と二重にしない (実行ファイルの名前が同じで、PATH の先頭の Homebrew 版が使われ、`dnf upgrade` で上がる方は使われない)
- `/home/linuxbrew/.linuxbrew` に入れた場合だけ、ビルド済みのボトルが使える。ほかの場所ではソースからのビルドになる
- root では動かない。`sudo -i` のシェルで実行すると、インストーラが止まる
- **Homebrew の依存に `python@3.x` が入ると、OS 全体で日本語が打てなくなることがある**。症状と対処は[注意点](../setup.md#注意点)

### brew の確認

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 10 に対応する。

- Neovim の依存は `libuv` / `lpeg` / `luajit` / `luv` / `tree-sitter` / `unibilium` / `utf8proc`。どれもボトルで降りる。`tree-sitter` はライブラリで、treesitter が使う CLI (`tree-sitter`) は Mason が入れる

### Neovim の版

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 11 に対応する。

- LazyVim 自身の下限は 0.11.2 (`:checkhealth lazyvim` の `Using Neovim >= 0.11.2`)
- Neovide で IME の未確定文字列を表示する機能 (`lua/config/ime_preedit.lua`) も 0.12 以上が要る
- 入手経路の比較は[選択した方針](#選択した方針)

### フォントと端末

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 12 に対応する。

- `lua/config/options.lua` の `guifont` (`HackGen Console NF:h12`) が効くのは Neovide などの GUI クライアントだけ。端末では端末側のフォント設定で決まる
- 別の Nerd Font を使うなら、端末の設定と `guifont` の両方を書き換える
- Neovim 側の `ambiwidth` は既定 (single) のままにしてある。**端末側だけを wide にすると、`○` `±` `①` などを含む行の桁が丸ごとずれる** (理由は `lua/config/options.lua` のコメント)
- cask の展開には `unzip` が要る (この節の手順 3 で入れた)

### 入力ソースを 2 つとも登録する理由

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 13 に対応する。

- IME 連携 (`lua/config/ime.lua`) は、ibus の global engine を `anthy` (日本語) と `xkb:us::eng` (英数) の間で切り替える。どちらも GNOME の入力ソースに登録しておかないと、gnome-shell が管理外のエンジンを巻き戻す
- 先頭の `export` は tmux の中で貼るときのため。tmux の中では `DBUS_SESSION_BUS_ADDRESS` が無いことがあり、そのとき `gsettings` は既定値しか読めず、書き込みも黙って効かない
- GNOME の端末ではもともと同じ値が入っているので、`export` しても変わらない
- **`/usr/bin/gsettings` と書く理由**: Homebrew の glib (cairo・ffmpeg・imagemagick・gnupg などの依存で入る) にも `gsettings` があり、`brew shellenv` の後は PATH の先頭に来る。これは dconf を使えず、`~/.config/glib-2.0/settings/keyfile` に黙って書くので、GNOME も Anthy も読まない
- Neovim から ibus への通信には `busctl` (systemd) か `gdbus` (glib2) を使う。`gdbus` があれば OS 側の切り替えも検知できるので、lualine の `あ` / `A` がずれない
- 実装と運用上の注意 (変換中の `<Esc>` は 2 回、Neovim を 2 つ起動したときの制限など) は [README の日本語入力・検索](../../README.md#日本語入力検索)

### Anthy のキーの書き換え方

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 14 に対応する。

- `on_off` は Anthy の中のひらがなと英字 (直接入力) を切り替えるキー。既定は `['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J']`
- 残したままだと `Ctrl+J` が Anthy に食われて Neovim の `<C-j>` が届かない。Anthy の中の切り替えは D-Bus から見えないので、lualine の表示も実際とずれる
- **Anthy の設定はスキーマの既定値とマージされない**。`on_off` だけの部分的な dict を書くと、ほかのキー割り当てが全部消える。そのため全体を読んで `on_off` だけを置き換える

### <code>lazy-lock.json</code> を戻してから restore する理由

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 16 に対応する。

- lazy.nvim は起動時に、足りないプラグインを `lazy-lock.json` の版で入れる。ただし初回は導入が何回かに分かれて走る
- 1 回目は LazyVim などの分だけを入れ、その時点で導入済みのものだけで `lazy-lock.json` を書き直す。そのため、2 回目以降に入るプラグインは記録の版ではなく最新になる
- `restore` の `!` は、終わるまで待ってから `+qa` に進ませるため。付けないと、取得の途中で `+qa` が終了させる
- 記録にある 39 個のうち render-markdown.nvim は無効にしてあるので、入るのは 38 個
- headless では画面が無いので `VeryLazy` が発火しない。treesitter のパーサー・Mason のツールの導入と、`lua/config/autocmds.lua` (IME 連携・CJK スペル・Markdown の conceal) は、この節の手順 17 の起動で動く
- `nvim --headless "+Lazy! sync" +qa` は update を含むので、`lazy-lock.json` より新しい版に上げてしまう。揃えるときは使わない
- 運用の方針は [README の lazy-lock.json の運用](../../README.md#lazy-lockjson-の運用)

### 初回起動で入るもの

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 17 に対応する。

- ファイルを開くのは、LSP のサーバーがファイルを開いたとき (`LazyFile`) に初めて入るため
- Mason が入れるのは 11 個: `bash-language-server` / `json-lsp` / `lua-language-server` / `markdownlint-cli2` / `marksman` / `shellcheck` / `shfmt` / `stylua` / `taplo` / `tree-sitter-cli` / `yaml-language-server`
- tree-sitter の CLI が PATH にあると (Homebrew の `tree-sitter-cli` など)、LazyVim は Mason で `tree-sitter-cli` を入れないので 10 個になる
- そのうち 4 個 (`bash-language-server` / `json-lsp` / `markdownlint-cli2` / `yaml-language-server`) は npm で入る
- 途中で閉じても、次に起動したときに足りないものが入る
- treesitter のパーサーは GitHub の archive から取得し、`gcc` でビルドする
- `ENOENT` の通知は、markdownlint-cli2 が入る前に開いたファイルを lint しようとしたもの。入った後の起動では出ない

### <code>checkhealth</code> の読み方

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 18 に対応する。

- `fzf` の WARNING は無視してよい。ピッカーは snacks.nvim の Lua 実装で、fzf を呼ばない
- `mason.nvim` を先に読み込むのは、Mason の `bin` が PATH に入るのが Mason を読み込んだときだけだから。読み込まないと `` ERROR `tree-sitter (CLI)` is not installed `` が出る
- `luamigemo` は `VeryLazy` で読み込まれるので、先に読み込まないと `No healthcheck found for "luamigemo" plugin.` になる
- `luamigemo` の節は、LuaJIT・同梱の辞書・モジュールの読み込みの 3 つが OK なら日本語検索が動く
- 画面で見るなら、Neovim の中で `:checkhealth lazyvim` / `:checkhealth mason` / `:checkhealth luamigemo`

### 機能の確かめ方

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 19 に対応する。

- 日本語検索は Migemo (luamigemo) で、ローマ字のまま日本語にマッチする。辞書は同梱なのでネットワークは要らない
- 英単語や空白・記号を含む入力はそのまま検索する (ローマ字として読めるときだけ変換する)
- `s` → `nihon` → `;` → ラベルで「日本語」の「日本」へ飛べることも見られる (flash.nvim。`;` を打つまではラベルで飛ばない)
- `<Tab>` の候補は、バッファ内で Migemo に一致した文字列を ripgrep で集めたもの。ローマ字が 3 文字以上のときだけ出る
- 整形は保存時に conform.nvim が `glfm_markdownlint` を掛ける。markdownlint-cli2 の修正候補のうち、説明リストの対応・所属・本文を保つものを反映する。`#動作確認` は MD018 (見出しの `#` の後の空白) の違反
- IME 連携は ibus-daemon が動いているセッションで起動したときだけ有効になる。ログインし直した後の端末で起動する

### Windows の外部コマンド

元の説明は [Windows 11 に導入する (1 度だけ)](../setup.md#windows-11-に導入する-1-度だけ)の手順 6 に対応する。

- `zenhan` / `neovim` / `ripgrep` / `fd` / `gcc` / `nodejs` は scoop の `main` バケット、`vcredist2022` / `lazygit` は `extras` にある (バケットの定義で確認)
- `curl` と `tar` は Windows 11 が `C:\Windows\System32` に同梱している
- scoop の `neovim` は VC++ のランタイム (`VCRUNTIME140.dll`) を同梱しない。`extras/vcredist2022` の提案だけでは自動導入されないため、この手順で先に入れて揃える ([注意点](../setup.md#注意点))
- ランタイムは `System32\vcruntime140.dll` が無いときだけ入れる。ほかのアプリや winget (`Microsoft.VCRedist.2015+.x64`) で入れてある PC で `vcredist2022` を入れると、x64・x86 の 2 つのインストーラーの UAC が余計に出るため
  - 見るのはファイルの有無だけで、版は見ない
  - `nvim.exe` は x64 なので、64 ビットの PowerShell (既定) で `System32` を見る。32 ビットの PowerShell では `System32` が `SysWOW64` に読み替えられ、x86 のランタイムを見てしまう
- `gzip` と `unzip` は要らない。Mason は Windows では zip を PowerShell の `Expand-Archive` で、`.tar.gz` を同梱の `tar` で展開する。この設定で入る 11 個は、どちらかか、展開の要らない exe・npm で済む
- `:checkhealth mason` の `unzip` / `gzip` / `wget` の WARNING は無視してよい
- C コンパイラは `gcc` が PATH にあれば、LazyVim が見つけて `CC` に設定する
- scoop を使わないなら `winget install --id=BrechtSanders.WinLibs.POSIX.UCRT` が手軽。Visual Studio Build Tools の `cl.exe` も自動で見つかる
- `zenhan` の代わりに `im-select` でもよい (scoop のバケットには無い)
- シェルは `pwsh` (PowerShell 7) があればそれを、無ければ `powershell` を使う (`lua/config/options.lua`)
- **Microsoft Store 版の PowerShell 7 は、PATH の上ではアプリ実行エイリアス (中身の無いファイル) で、Neovim は実行ファイルと判定しない**。pwsh の中から起動した nvim でだけ `pwsh` になり、エクスプローラーやスタートメニューから起動した Neovide などでは `powershell` (5.1) になる。どちらでも動く
- どこから起動しても `pwsh` にしたいなら、`scoop install pwsh` など、PATH にエイリアスではない `pwsh.exe` が載る入れ方にする
- Neovide を使うなら **Neovide 0.16 以上 + Neovim 0.12 以上**にする。それより古いと IME の未確定文字列が確定まで表示されない

### 拡張がしていること

元の説明は [GNOME の上部バーを IME 連携に合わせる (任意)](../setup.md#gnome-の上部バーを-ime-連携に合わせる-任意)の手順 4 に対応する。

- GNOME Shell 49.4 の `ui/status/keyboard.js` は、自分で入力ソースを切り替えたとき (`activateInputSource()`) だけ「今の入力ソース」を書き換える。`misc/ibusManager.js` は、ibus の `GlobalEngineChanged` を受けても engine の名前を控えるだけ
- 拡張は同じシグナルを受け、今の入力ソースが engine と違えば、`InputSourceManager` の `_currentInputSourceChanged()` (内部の関数) で今の入力ソース・上部バーの表示・Super+Space の順番 (MRU) を更新する
- `activateInputSource()` を呼ばないのは、キーボードを一時的に掴むため。掴むと端末にフォーカスの出入りが届き、engine も設定し直してしまう
- GNOME Shell 自身の切り替え (Super+Space) では、シグナルが届く前に今の入力ソースが更新済みなので何もしない。ibus は同じ engine を設定し直してもシグナルを出さないので、行き来は起きない
- パスワード欄にいる間 (GNOME Shell が ibus を止めて英数に切り替えている間) は何もしない
- 内部の関数が無くなったら何もしない (上部バーがずれるだけの、この節を行う前の状態に戻る)

### トークンの置き場所

元の説明は [GitLab プレビューのトークンを設定する (任意)](../setup.md#gitlab-プレビューのトークンを設定する-任意)の手順 3 に対応する。

元の説明は [GitLab プレビューのトークンを設定する (任意)](../setup.md#gitlab-プレビューのトークンを設定する-任意)の手順 1 に対応する。

- `~/.bashrc` は平文。ホームディレクトリは自分だけが読める (0700) ので、ほかのユーザーからは読めない
- GNOME から起動する GUI のアプリ (Neovide など) は `~/.bashrc` を読まない。そちらでも使うなら、`~/.config/environment.d/gitlab.conf` に `GITLAB_TOKEN=…` の形で書き、ログインし直す
- 名前は GitLab の CLI (glab) と同じにしてある

### トークンの置き場所

- ユーザーの環境変数は、レジストリ (`HKCU\Environment`) に平文で入る。ほかのユーザーからは読めない
- 設定した後に起動したアプリ (端末・スタートメニューから開く Neovide) にだけ渡る。開いたままの端末には渡らない

### 仕組みと、手元から Neovim への向き

元の説明は [SSH 越しのヤンクを手元のクリップボードに送る (任意)](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 2 に対応する。

- ヤンクや削除のたびに、Neovim が OSC 52 (中身を base64 にしたエスケープシーケンス) を画面に書き、WezTerm がそれを手元のクリップボードに入れる。SSH は画面の出力として運ぶだけ
- LazyVim は SSH のシェルでは `clipboard` を空にするので、そのままでは `yy` が手元に入らない (WezTerm の nightly なら、`"+yy` は入る)
- Neovim は `clipboard` が空のときしか OSC 52 を自動で選ばない。この設定は `lua/config/options.lua` で OSC 52 を明示し、`clipboard` をローカルと同じ `unnamedplus` にしている
- `p` は端末に問い合わせず、この Neovim が最後に送った内容を貼る (行単位・矩形の形も保つ)。OSC 52 の読み出しには WezTerm も Windows Terminal も応えず、Neovim の内蔵の読み出しは 1 回ごとに 10 秒待つため
- 手元でコピーしたものは、WezTerm の貼り付け (Ctrl+Shift+V) で入れる。Neovim には貼り付け (bracketed paste) として届き、挿入モードでもノーマルモードでもカーソルの後ろに入る。レジスタには入らない
- ローカル (GNOME の端末や Neovide) で起動したときは、これまでどおり `wl-copy` などを使う (`SSH_CONNECTION` が無いので、この節の設定は効かない)

### 選択した方針


**Neovim の入手経路** (Linux):

| 経路 | 状況 | 採否 |
|---|---|---|
| **Homebrew** | x86_64 / aarch64 ともボトルがあり、ソースビルドを待たずに最新版が入る | **採用** |
| EPEL の `neovim` | 0.10.1。0.12 に届かない | 不採用 |
| 公式リリースの tar.gz | `nvim-linux-x86_64.tar.gz` / `nvim-linux-arm64.tar.gz` を展開して PATH を通す | 不採用 (更新が手作業) |
| AppImage | **FUSE が要る**。FUSE の無い環境では `fuse: device not found` で起動しない | 不採用 |
- **パッケージマネージャ**: Windows は scoop を使う (管理者権限が要らず、`%USERPROFILE%\scoop` に収まる)
  - winget や手動のインストールでもよいが、その場合は各コマンドが PATH に載っていることだけ確かめる
  - この設定はコマンドの場所をハードコードせず、`executable()` で PATH を見て機能を出し入れする
- **変数を置かない**: 以前の版は clone 先と URL を変数にしていたが、どちらも変える必要が無い
  - Neovim は既定の場所しか読まないので、clone 先の変数を変えても読み込み先は変わらなかった
- **初回は headless で入れて、`lazy-lock.json` を戻してから restore する**: 初回の導入が lock を書き換えるため ([AlmaLinux 導入の手順 16](../setup.md#almalinux-10-に導入する-1-度だけ) の補足)
  - 画面を開く前に揃えるので、初回起動からほかのマシンと同じ版で動く
- **入力ソースは `us` と `anthy` に固定する**: IME 連携が英数を `xkb:us::eng` に固定しているため ([AlmaLinux 導入の手順 13](../setup.md#almalinux-10-に導入する-1-度だけ) の補足)
- **フォントは Linux では Homebrew の cask にする**: zip を落として `~/.local/share/fonts` に置く手作業が 1 行になり、`brew upgrade --cask` で上がる。Windows には同じ手段が無いので手で入れる
- **動作確認は試験用のファイルで行う**: `/tmp` の Markdown 1 つで、LSP の導入の引き金・日本語検索・整形の 3 つを確かめられる
- **GitLab プレビューの設定は環境変数にする**: 名前は GitLab の CLI (glab) と同じ `GITLAB_TOKEN` / `GITLAB_HOST`
  - この設定のファイル (git で追跡し、ほかのマシンにも配る) にトークンを書かないため
  - トークンと URL は文書に書かず、貼った後に入力させる ([トークンの節](../setup.md#gitlab-プレビューのトークンを設定する-任意))
- **SSH 越しのクリップボードは OSC 52 にし、向きは Neovim → 手元だけにする** ([SSH の節](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)): 端末が運ぶので、手元にも AlmaLinux 10 にもソフトを足さずに済む
  - X11 転送 (`ssh -X` と xclip) は、手元に X サーバーが要る。lemonade などの中継は、転送したポートを同じサーバーのほかのユーザーも使える
  - 手元 → Neovim の向きには OSC 52 の読み出しが要るが、WezTerm (nightly を含む) と Windows Terminal は応えない。端末の貼り付けで足りるので扱わない
  - Neovim が OSC 52 を自動で選ぶのは `clipboard` が空のときだけで、`"+y` のように明示したときしか入らない。`y` でも入れるため、`lua/config/options.lua` で明示して `unnamedplus` にする
  - 明示すれば、端末の検出にも頼らない。WezTerm の nightly は DA1 に `52` を出すので検出されるが、出さない端末では XTGETTCAP の応答頼みになり、noice がその応答を受け取らせない (folke/noice.nvim#1229)

### 参照

- [LazyVim のインストール](https://lazyvim.github.io/installation): 要求される外部コマンドと初回起動の流れ
- [lazy.nvim](https://lazy.folke.io/): `:Lazy restore` と `lazy-lock.json` の扱い
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux): `/home/linuxbrew/.linuxbrew` に入れる理由とボトルの条件
- [scoop](https://scoop.sh/): 管理者権限なしで `%USERPROFILE%\scoop` に入れる
- [Visual C++ 再頒布可能パッケージ](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files#command-line-options-for-the-redistributable-packages): インストーラーのオプションと、非管理者から起動するときの UAC
- [luamigemo](https://github.com/delphinus/luamigemo): ローマ字検索 (Migemo) の純 Lua 実装。同梱の辞書のライセンスもここ
- [ibus-anthy](https://github.com/ibus/ibus-anthy): `on_off` などのキー割り当て
- [HackGen](https://github.com/yuru7/HackGen): フォントのリリース
- [GitLab の Markdown API](https://docs.gitlab.com/api/markdown/): GitLab プレビューが呼ぶ API。認証が要ること (`read_api` で足りる) と `project` の扱い
- [GitLab Flavored Markdown](https://docs.gitlab.com/user/markdown/): GLFM の記法 (スニペットと近似表示が扱う記法の出どころ)
- [GitLab の個人アクセストークン](https://docs.gitlab.com/user/profile/personal_access_tokens/): トークンの作り方とスコープ
- [img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim): 画像の貼り付けの設定項目
- [Neovim の clipboard-osc52](https://neovim.io/doc/user/provider/#clipboard-osc52): OSC 52 の提供元と、自動検出が効く条件 (`clipboard` が空のときだけ)
- [wezterm#5917](https://github.com/wezterm/wezterm/issues/5917): 設定ファイルがあると OSC 52 が効かない (nightly で直った)
- [folke/noice.nvim#1229](https://github.com/folke/noice.nvim/issues/1229): noice が XTGETTCAP の応答を受け取らせず、DA1 に `52` を出さない端末では OSC 52 の自動検出が効かない
- [README](../../README.md): この設定で何ができるか、IME 連携の設計と運用上の注意
