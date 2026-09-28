# Neovim 設定 (LazyVim) の導入手順 (AlmaLinux 10 + GNOME / Windows 11)

## 実施手順

> [!IMPORTANT]
> - **AlmaLinux 10 では、GNOME にログインしたデスクトップの端末で、自分のユーザーのまま実行する**。`sudo -i` した root のシェルでは行わない (Homebrew は root で動かず、`gsettings` は実行したユーザーの設定しか変えない)
> - **AlmaLinux 10 で実行するユーザーは `sudo` できる必要がある** ([AlmaLinux 導入の手順 2・3・8](#almalinux-10-に導入する-1-度だけ))
> - **Windows 11 では、管理者ではない PowerShell で実行する**
> - **対話入力がある**: AlmaLinux 導入の手順 3 (`[y/N]` と EPEL の鍵)、手順 8 (Homebrew の `RETURN` と `sudo` のパスワード)、手順 10 (`brew` の `[y/n]`)。答えてから次の手順を貼る
> - **Neovim の画面が開く**: AlmaLinux 導入の手順 17・19、Windows 導入の手順 9・11。`:qa` で閉じてから次の手順を貼る
> - **AlmaLinux 導入の手順 15 の後で、ログアウトしてログインし直す** (入れた ibus-anthy と入力ソースを読み直させる)

| シナリオ | 頻度 | 内容 |
|---|---|---|
| [AlmaLinux 10 に導入する](#almalinux-10-に導入する-1-度だけ) | マシンごとに 1 度 | 外部コマンド・Neovim・日本語入力・フォントを入れ、この設定を clone して初回起動する |
| [Windows 11 に導入する](#windows-11-に導入する-1-度だけ) | マシンごとに 1 度 | scoop で外部コマンド・Neovim・zenhan を入れ、この設定を clone して初回起動する |
| [ほかのマシンの変更を取り込む](#ほかのマシンの変更を取り込む-繰り返し) | 繰り返し | 別のマシンで push した設定と `lazy-lock.json` を取り込み、プラグインの版を揃える |
| [カーソル色を tmux で効かせる (任意)](#カーソル色を-tmux-で効かせる-任意) | 任意、1 度だけ | tmux の中でも、挿入モードのカーソル色を IME の状態で変える (AlmaLinux 10) |
| [更新](#更新) | 更新のたび | Neovim・外部コマンド・プラグインを上げる |
| [ロールバック](#ロールバック) | 戻すとき | この設定とプラグインを消し、退避した設定と入力ソースを戻す |

- 初めてのマシンでは、自分の OS の「導入する」を上から順に貼る。以後は、必要なシナリオと節だけを貼る
- 手順の番号はシナリオ (見出し) ごとに 1 から数える。ほかのシナリオの手順は「AlmaLinux 導入の手順 3」「Windows 導入の手順 2」「取り込みの手順 1」のように呼ぶ
- 変数は無い。設定の置き場所 (`~/.config/nvim` / `%LOCALAPPDATA%\nvim`) と clone 元の URL は、コマンドに直接書いてある
- AlmaLinux 10 のブロックは bash、Windows 11 のブロックは PowerShell で貼る
- 各手順の末尾の「補足」(折り畳み) と後半の[補足](#補足)は、実行するだけなら読まなくてよい。折り畳みの中のブロックも貼らなくてよい
- この設定で何ができるかは [README](../README.md)。外部コマンドの用途は[必要なもの一覧](#必要なもの一覧)

> [!WARNING]
> **AlmaLinux 10 の手順は x86_64 のコンテナでのみ通した**。GNOME の画面と aarch64 では通していない。**Windows 11 の手順は実機で通したが、IME の切り替えは確かめていない** (zenhan をモックに差し替えた)。範囲は[対象と検証環境](#対象と検証環境)。

### AlmaLinux 10 に導入する (1 度だけ)

- AlmaLinux 10 + GNOME の PC に、外部コマンド・Neovim・日本語入力・フォントを入れ、この設定を `~/.config/nvim` に clone して初回起動する
- 外部コマンドを全部入れてから初回起動する。この設定はコマンドの有無を見て機能を出し入れするので、足りないとエラーにならずに静かに壊れる ([注意点](#注意点))
- マシンごとに 1 度だけ行う。以後は[ほかのマシンの変更を取り込む](#ほかのマシンの変更を取り込む-繰り返し)と[更新](#更新)

1. EPEL が有効になっているか確かめる。

   ```bash
   dnf repolist enabled | grep -E '^epel' || echo 'EPEL は未設定'
   ```

   - `epel` の行が出れば、この節の手順 2 は飛ばす
   - `EPEL は未設定` と出たら、この節の手順 2 で入れる

1. EPEL が未設定のときだけ、`epel-release` を入れる。

   ```bash
   sudo dnf install -y epel-release
   ```

   - 最後に CRB を勧めるメッセージが出るが、この設定には要らない
   - **次の手順は、`sudo` のパスワードを聞かれたら答えてから貼る** (続けて貼ると答えとして食われる)

   <details>
   <summary>補足: EPEL が要る理由</summary>

   - `ripgrep` と `fd-find` は AlmaLinux の BaseOS / AppStream に無く、EPEL にある。EPEL を入れずにこの節の手順 3 を貼ると `Unable to find a match: ripgrep fd-find` で止まる
   - `epel-release` は AlmaLinux の `extras` リポジトリにあり、追加のリポジトリ設定は要らない。弱い依存として `dnf-plugins-core` も入る
   - 最後の `Many EPEL packages require the CodeReady Builder (CRB) repository.` は、この節で入れるものには当てはまらない (CRB を有効にせずに通した)

   </details>

1. 外部コマンドと日本語入力 (ibus-anthy) を dnf で入れる。

   ```bash
   sudo dnf install git ripgrep fd-find gcc curl tar gzip unzip nodejs nodejs-npm file procps-ng ibus-anthy
   ```

   - 何に使うかは[必要なもの一覧](#必要なもの一覧)
   - EPEL の署名鍵をまだ取り込んでいなければ、ここで 1 回だけ確認を求められる
   - 鍵の fingerprint が `7D8D 15CB FC4E 6268 8591 FB26 33D9 8517 E37E D158` (`Fedora (epel10)`) であることを確かめてから `y` と答える
   - **次の手順は、トランザクション表の `[y/N]` と鍵の確認に答えてから貼る** (続けて貼ると答えとして食われる)

   <details>
   <summary>補足: dnf で入れるもの</summary>

   - **`unzip` は必須**: Mason は zip で配布されるツール (`stylua` など) の展開に使う。無いと**そのツールだけ**が静かに入らず、ほかは入るので気付きにくい
   - **`gcc`**: nvim-treesitter は各言語のパーサーを手元で C としてコンパイルする。C コンパイラが無いとハイライトが効かない
   - **`nodejs` / `nodejs-npm`**: Mason が `markdownlint-cli2` / `markdown-toc` / `bash-language-server` / `json-lsp` / `yaml-language-server` を npm パッケージとして入れる。**node を消すと Markdown の lint と整形が丸ごと止まる**
   - `npm` と書いても `nodejs-npm` に解決されて入るが、この節の手順 4 の `rpm -q` はパッケージ名でしか引けないので、両方の手順で `nodejs-npm` と書いている
   - **`file` / `procps-ng`**: Homebrew の前提 (この節の手順 8)。GNOME の PC には入っていることが多い
   - **`ibus-anthy`**: AlmaLinux 10 の Workstation には最初から入っている。入っていれば dnf は `already installed` と出して飛ばす。依存として `ibus-anthy-python` と `anthy-unicode` が入る
   - `curl` / `tar` / `gzip` は treesitter と Mason の取得・展開に使う。最小構成のコンテナにも入っていた
   - **Deno は要らない**: 日本語のローマ字検索 (Migemo) は純 Lua の luamigemo が辞書ごと同梱している
   - コンテナ (最小構成の `almalinux:10`) での実測は、101 個を入れて 4 個を更新した (git の依存の perl など)。GNOME の PC ではもっと少ない

   </details>

1. dnf で入ったか確かめる。

   ```bash
   rpm -q git ripgrep fd-find gcc curl tar gzip unzip nodejs nodejs-npm file procps-ng ibus-anthy
   node --version
   command -v fd rg gdbus busctl
   ```

   - どの行も `package … is not installed` にならなければよい
   - `node --version` が `v22.…` と出る
   - `fd` / `rg` / `gdbus` / `busctl` の 4 つの場所が出る (`gdbus` と `busctl` は IME 連携が ibus と話すのに使う)

1. 既存の Neovim の設定とデータがあれば、`.bak` を付けて退避する。

   ```bash
   for d in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim; do
     [ ! -e "${d}" ] || mv -vT "${d}" "${d}.bak"
   done
   ```

   - 退避したものは `renamed '…/nvim' -> '…/nvim.bak'` と出る。何も出なければ、退避するものは無かった
   - **注意**: `.bak` がすでにあると `mv` が `cannot overwrite` で止まる。古い `.bak` を片付けてから、この手順を貼り直す
   - 戻し方は[ロールバック](#ロールバック)

   <details>
   <summary>補足: 退避するもの</summary>

   - `~/.config/nvim` は設定、`~/.local/share/nvim` はプラグインと Mason のツール、`~/.local/state/nvim` は undo・shada・ログ、`~/.cache/nvim` はキャッシュ
   - Neovim を入れる前 (この節の手順 10 より前) に置いたのは、`nvim --version` を 1 回実行しただけで `~/.local/state/nvim` ができるため (コンテナで確認)
   - Neovim が初めてのマシンでは何も起きない

   </details>

1. この設定を `~/.config/nvim` に clone する。

   ```bash
   [ -e ~/.config/nvim/init.lua ] || git clone https://github.com/ryo-aoki-pc/LazyVimStarter.git ~/.config/nvim
   git -C ~/.config/nvim branch --show-current
   ```

   - `custom` と出ればよい (実運用の設定のブランチで、このリポジトリの既定のブランチ)
   - すでに clone してあれば、`git clone` は飛ばされる

   <details>
   <summary>補足: clone 先</summary>

   - **このリポジトリが Neovim の設定ディレクトリそのもの**なので、clone 先は `~/.config/nvim` にする。Neovim は `$XDG_CONFIG_HOME/nvim` (未設定なら `~/.config/nvim`) しか読まない
   - 別の場所に置くなら `NVIM_APPNAME` か `XDG_CONFIG_HOME` を設定する (本書では扱わない)
   - clone 元は HTTPS の URL にしてある。公開リポジトリなので鍵は要らない。`git@github.com:` の形は、SSH 鍵を GitHub に登録していない新しいマシンでは `Host key verification failed` で失敗する
   - `main` ブランチは LazyVim starter の上流の写しで、この設定は入っていない

   </details>

1. Homebrew が入っているか確かめる。

   ```bash
   command -v brew || echo 'Homebrew は未導入'
   ```

   - `brew` の場所が出れば、この節の手順 8 は飛ばす
   - `Homebrew は未導入` と出たら、この節の手順 8 で入れる

1. Homebrew が未導入のときだけ、公式のインストーラを実行する。

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

   - `/home/linuxbrew/.linuxbrew` に入る。導入先は変えない
   - 途中で `sudo` のパスワードと `Press RETURN/ENTER to continue` を求められる
   - `==> Installation successful!` が出れば終わり。`Next steps` の案内は、この節の手順 9 が代わりに行う
   - **次の手順は、インストーラが終わってから貼る** (続けて貼ると `RETURN` の答えとして食われる)

   <details>
   <summary>補足: Homebrew を使う理由と導入先</summary>

   - Neovim を Homebrew で入れるため (EPEL の Neovim は古い。[選択した方針](#選択した方針))
   - `/home/linuxbrew/.linuxbrew` に入れた場合だけ、ビルド済みのボトルが使える。ほかの場所ではソースからのビルドになる
   - root では動かない。`sudo -i` のシェルで実行すると、インストーラが止まる
   - `Next steps` の `sudo dnf group install development-tools` は、この設定には要らない (入れずに通した)
   - **Homebrew の依存に `python@3.x` が入ると、OS 全体で日本語が打てなくなることがある**。症状と対処は[注意点](#注意点)

   </details>

1. `~/.bashrc` に 1 行書き、`brew` を PATH に入れる。

   ```bash
   grep -qF 'brew shellenv' ~/.bashrc || echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> ~/.bashrc
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
   brew --version
   ```

   - `Homebrew 7.…` と版が出ればよい
   - すでに `brew shellenv` の行があれば、`~/.bashrc` には足さない
   - ほかの端末は、開き直すと `brew` が使える

1. Neovim と lazygit を Homebrew で入れる。

   ```bash
   brew install neovim lazygit
   ```

   - 入るものの一覧 (依存 7 つを含む) の後に `Do you want to proceed with the installation? [y/n]` と聞かれる。`y` と答える
   - lazygit は任意 (無ければ `<leader>gg` が定義されないだけ)
   - **次の手順は、`[y/n]` に答えてインストールが終わってから貼る** (続けて貼ると答えとして食われる)

   <details>
   <summary>補足: brew の確認</summary>

   - 検証した Homebrew 7.0.7 は、依存のある formula を入れる前に確認を求めた (`==> Would install 2 formulae:` → `==> Would install 7 dependencies for neovim:` → `[y/n]`)
   - 依存の無い cask (この節の手順 12) では、確認は出なかった
   - 依存は `libuv` / `lpeg` / `luajit` / `luv` / `tree-sitter` / `unibilium` / `utf8proc`。どれもボトルで降りる。`tree-sitter` はライブラリで、treesitter が使う CLI (`tree-sitter`) は Mason が入れる

   </details>

1. Neovim と lazygit が入ったか確かめる。

   ```bash
   nvim --version | head -1
   command -v nvim lazygit
   ```

   - `NVIM v0.12.…` と出ればよい (0.12 以上が要る)
   - 2 つとも `/home/linuxbrew/.linuxbrew/bin/…` と出る

   <details>
   <summary>補足: Neovim の版</summary>

   - LazyVim 自身の下限は 0.11.2 (`:checkhealth lazyvim` の `Using Neovim >= 0.11.2`)
   - ただし `lazy-lock.json` に記録した nvim-treesitter (main ブランチ) は Neovim 0.12 以上を要求する。0.11 系では試していない
   - Neovide で IME の未確定文字列を表示する機能 (`lua/config/ime_preedit.lua`) も 0.12 以上が要る
   - 入手経路の比較は[選択した方針](#選択した方針)

   </details>

1. フォント HackGen Console NF を Homebrew の cask で入れる。

   ```bash
   brew install --cask font-hackgen-nerd
   fc-match 'HackGen Console NF'
   ```

   - `HackGenConsoleNF-Regular.ttf: "HackGen Console NF" "Regular"` と出ればよい
   - フォントは `~/.local/share/fonts` に入る
   - 端末 (GNOME Terminal / WezTerm など) のフォントを HackGen Console NF にする。しないと、アイコンが豆腐 (□) になる
   - WezTerm では `treat_east_asian_ambiguous_width_as_wide` を既定 (false) のままにする (この手順の補足)

   <details>
   <summary>補足: フォントと端末</summary>

   - `lua/config/options.lua` の `guifont` (`HackGen Console NF:h12`) が効くのは Neovide などの GUI クライアントだけ。端末では端末側のフォント設定で決まる
   - 別の Nerd Font を使うなら、端末の設定と `guifont` の両方を書き換える
   - Neovim 側の `ambiwidth` は既定 (single) のままにしてある。**端末側だけを wide にすると、`○` `±` `①` などを含む行の桁が丸ごとずれる** (理由は `lua/config/options.lua` のコメント)
   - cask の展開には `unzip` が要る (この節の手順 3 で入れた)
   - コンテナでは、`~/.local/share/fonts` に 4 ファイル (`HackGenConsoleNF-{Regular,Bold}.ttf` と `HackGen35ConsoleNF-{Regular,Bold}.ttf`) が入った。`fc-cache` は要らなかった

   </details>

1. 入力ソースを「英語 (US)」と Anthy の 2 つにする。

   ```bash
   export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
   gsettings get org.gnome.desktop.input-sources sources
   gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'anthy')]"
   gsettings get org.gnome.desktop.input-sources sources
   ```

   - 最後の行が `[('xkb', 'us'), ('ibus', 'anthy')]` になればよい
   - 最初の行は変える前の値。ほかの入力ソースは消える
   - 日本語と英数の切り替えは Super+Space になる
   - **注意**: JIS 配列のキーボードでも `us` にする。IME 連携が英数を `xkb:us::eng` に固定しているため (この手順の補足)

   <details>
   <summary>補足: 入力ソースを 2 つとも登録する理由</summary>

   - IME 連携 (`lua/config/ime.lua`) は、ibus の global engine を `anthy` (日本語) と `xkb:us::eng` (英数) の間で切り替える。どちらも GNOME の入力ソースに登録しておかないと、gnome-shell が管理外のエンジンを巻き戻す
   - 英数のエンジン名は `ime.lua` の中で `xkb:us::eng` に固定してある。入力ソースを `('xkb', 'jp')` にすると、Neovim が英数に戻すたびに US 配列のエンジンになる (コードから読んだもので、JIS 配列では試していない)
   - 先頭の `export` は tmux の中で貼るときのため。tmux の中では `DBUS_SESSION_BUS_ADDRESS` が無いことがあり、そのとき `gsettings` は既定値しか読めず、書き込みも黙って効かない
   - GNOME の端末ではもともと同じ値が入っているので、`export` しても変わらない
   - Neovim から ibus への通信には `busctl` (systemd) か `gdbus` (glib2) を使う。`gdbus` があれば OS 側の切り替えも検知できるので、lualine の `あ` / `A` がずれない
   - 実装と運用上の注意 (変換中の `<Esc>` は 2 回、Neovim を 2 つ起動したときの制限など) は [README の日本語入力・検索](../README.md#日本語入力検索)

   </details>

1. Anthy の `on_off` のキーから `Ctrl+J` と `Ctrl+space` を外した値を作る。

   ```bash
   ANTHY_SHORTCUT=$(gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | sed "s/'on_off': <\['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J'\]>/'on_off': <['Zenkaku_Hankaku']>/")
   printf '%s\n' "${ANTHY_SHORTCUT}" | grep -o "'on_off': <\[[^]]*\]>"
   ```

   - `'on_off': <['Zenkaku_Hankaku']>` と出ればよい
   - `Ctrl+J` が残っている・何も出ないときは、この節の手順 15 は飛ばす。代わりに `ibus-setup-anthy` の「キー割り当て」で `on_off` から `Ctrl+J` と `Ctrl+space` を消す
   - **次の手順は、出た行を目で確かめてから貼る**

   <details>
   <summary>補足: Anthy のキーの書き換え方</summary>

   - `on_off` は Anthy の中のひらがなと英字 (直接入力) を切り替えるキー。既定は `['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J']`
   - 残したままだと `Ctrl+J` が Anthy に食われて Neovim の `<C-j>` が届かない。Anthy の中の切り替えは D-Bus から見えないので、lualine の表示も実際とずれる
   - **Anthy の設定はスキーマの既定値とマージされない**。`on_off` だけの部分的な dict を書くと、ほかのキー割り当てが全部消える。そのため全体を読んで `on_off` だけを置き換える
   - コンテナの ibus-anthy 1.5.17 では、既定値は 46 個のキーを持つ dict で、この sed で `on_off` だけが変わり、46 個のまま残った

   </details>

1. 作った値を Anthy の設定に書き戻す。

   ```bash
   gsettings set org.freedesktop.ibus.engine.anthy.shortcut default "${ANTHY_SHORTCUT:?AlmaLinux 導入の手順 14 の ANTHY_SHORTCUT が空のまま。AlmaLinux 導入の手順 14 を貼り直す}"
   gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | grep -o "'on_off': <\[[^]]*\]>"
   ```

   - `'on_off': <['Zenkaku_Hankaku']>` と出ればよい
   - 以後、日本語と英数の切り替えは Super+Space と、Neovim の中の `<C-j>` になる
   - **次の手順は、ログアウトしてログインし直してから貼る** (ibus-daemon に Anthy と入力ソースを読み直させる)

1. プラグインを入れ、`lazy-lock.json` の版に揃える。

   ```bash
   nvim --headless +qa
   git -C ~/.config/nvim checkout -- lazy-lock.json
   nvim --headless "+Lazy! restore" +qa
   git -C ~/.config/nvim status --short
   ```

   - 1 行目で lazy.nvim が自分を clone し、プラグイン 38 個を入れる。数分かかる
   - 終わりに `Neovim is exiting while packages are still installing.` や `Unmet requirements for **nvim-treesitter**`、`Error in command line` が出てよい (Mason と treesitter の導入が打ち切られただけで、この節の手順 17 で入り直す)
   - 最後の `git status --short` が何も出さなければ、`lazy-lock.json` の版に揃っている
   - **次の手順は、プロンプトが戻ってから貼る** (最後のメッセージの行末に続けて出ることがある)

   <details>
   <summary>補足: <code>lazy-lock.json</code> を戻してから restore する理由</summary>

   - lazy.nvim は起動時に、足りないプラグインを `lazy-lock.json` の版で入れる。ただし初回は導入が何回かに分かれて走る
   - 1 回目は LazyVim などの分だけを入れ、その時点で導入済みのものだけで `lazy-lock.json` を書き直す。そのため、2 回目以降に入るプラグインは記録の版ではなく最新になる
   - コンテナでは、1 行目の後に `lazy-lock.json` の 6 個 (nvim-treesitter・nvim-lspconfig・gitsigns.nvim など) が最新の版に書き換わった
   - 2 行目で記録を git から戻し、3 行目の `restore` でその版にチェックアウトし直す。これで `git status --short` が空になった
   - `restore` の `!` は、終わるまで待ってから `+qa` に進ませるため。付けないと、取得の途中で `+qa` が終了させる
   - 記録にある 39 個のうち render-markdown.nvim は無効にしてあるので、入るのは 38 個
   - headless では画面が無いので `VeryLazy` が発火しない。treesitter のパーサー・Mason のツールの導入と、`lua/config/autocmds.lua` (IME 連携・CJK スペル・Markdown の conceal) は、この節の手順 17 の起動で動く
   - `nvim --headless "+Lazy! sync" +qa` は update を含むので、`lazy-lock.json` より新しい版に上げてしまう (コンテナで 6 個が変わった)。揃えるときは使わない
   - 運用の方針は [README の lazy-lock.json の運用](../README.md#lazy-lockjson-の運用)

   </details>

1. 試験用の Markdown を開いて、treesitter と Mason の導入を待つ。

   ```bash
   printf '%s\n' '#動作確認' '' '日本語の検索を試す。' > /tmp/lazyvim-check.md
   nvim /tmp/lazyvim-check.md
   ```

   - 画面の下に `Downloading tree-sitter-…` などの通知が流れる
   - `:Mason` を開き、Installed が 12 個になり、導入中のものが無くなるまで待つ (`q` で閉じる)
   - 待ったら `:qa` で閉じる
   - **次の手順は、`:qa` で閉じてから貼る** (続けて貼ると Neovim への入力として食われる)

   <details>
   <summary>補足: 初回起動で入るもの</summary>

   - ファイルを開くのは、LSP のサーバーがファイルを開いたとき (`LazyFile`) に初めて入るため
   - Mason が入れるのは 12 個: `bash-language-server` / `json-lsp` / `lua-language-server` / `markdown-toc` / `markdownlint-cli2` / `marksman` / `shellcheck` / `shfmt` / `stylua` / `taplo` / `tree-sitter-cli` / `yaml-language-server`
   - そのうち 5 個 (`bash-language-server` / `json-lsp` / `markdown-toc` / `markdownlint-cli2` / `yaml-language-server`) は npm で入る
   - コンテナでは、開いてから 15 秒ほどで 12 個が揃い、`:Mason` に `Installed (12)` と出た
   - 途中で閉じても、次に起動したときに足りないものが入る (コンテナで確認)
   - treesitter のパーサーは GitHub の archive から取得し、`gcc` でビルドする
   - 検証環境ではパーサーの取得がプロキシに拒まれ、パーサーの導入は確かめていない ([付録](#付録-コンテナでの検証記録-2026-09-28))

   </details>

1. 外部コマンドと Mason のツールが揃ったかを、`checkhealth` で確かめる。

   ```bash
   ls ~/.local/share/nvim/mason/bin
   nvim --headless "+Lazy! load mason.nvim luamigemo" "+checkhealth lazyvim luamigemo" "+w! /tmp/lazyvim-health.txt" +qa
   grep -E 'ERROR|WARNING' /tmp/lazyvim-health.txt
   ```

   - `mason/bin` に `markdownlint-cli2` / `markdown-toc` / `marksman` / `stylua` / `tree-sitter` などが並ぶ
   - `grep` の結果が `` WARNING `fzf` is not installed `` の 1 行だけならよい (無視してよい)
   - `ERROR` が出たら[注意点](#注意点)

   <details>
   <summary>補足: <code>checkhealth</code> の読み方</summary>

   - `fzf` の WARNING は無視してよい。ピッカーは snacks.nvim の Lua 実装で、fzf を呼ばない
   - `mason.nvim` を先に読み込むのは、Mason の `bin` が PATH に入るのが Mason を読み込んだときだけだから。読み込まないと `` ERROR `tree-sitter (CLI)` is not installed `` が出る
   - `luamigemo` は `VeryLazy` で読み込まれるので、先に読み込まないと `No healthcheck found for "luamigemo" plugin.` になる
   - `luamigemo` の節は、LuaJIT・同梱の辞書・モジュールの読み込みの 3 つが OK なら日本語検索が動く
   - 画面で見るなら、Neovim の中で `:checkhealth lazyvim` / `:checkhealth mason` / `:checkhealth luamigemo`

   </details>

1. 試験用の Markdown を開き、日本語検索・整形・IME 連携を確かめる。

   ```bash
   nvim /tmp/lazyvim-check.md
   ```

   - `/kensaku` と打って Enter を押す。3 行目の「検索」にカーソルが移り、`[1/1]` と出る
   - `/kensaku` と打って `<Tab>` を押す。入力が「検索」に置き換わる (候補が 1 つなので、すぐ確定する)。`<Esc>` で抜ける
   - `:w` で保存する。1 行目が `# 動作確認` に直る (markdownlint-cli2 の整形)
   - `o` で行を開き、`<C-j>` を押す。下の表示が `A` から `あ` に変わる。`<Esc>` で `A` に戻る
   - `/` の中で `<C-j>` を押し、`<Esc>` で抜ける。表示が `A` に戻り、次の `/` は `あ` で始まる (検索の sticky)。`<C-j>` で `A` にしてから `<Esc>` で抜ける
   - `<C-j>` を押したときは、カーソルのすぐ下にも `あ` / `A` が約 1 秒出る
   - Space を 2 回押してファイルピッカーを開き、アイコンが豆腐でないことを見る (`<Esc>` で閉じる)
   - `:qa!` で閉じる (`o` で足した行は保存しない)
   - これで導入は終わり

   <details>
   <summary>補足: 機能の確かめ方</summary>

   - 日本語検索は Migemo (luamigemo) で、ローマ字のまま日本語にマッチする。辞書は同梱なのでネットワークは要らない
   - 英単語や空白・記号を含む入力はそのまま検索する (ローマ字として読めるときだけ変換する)
   - `s` → `ni` で「日本語」などにラベルが付くことも見られる (flash.nvim)。同梱の辞書に「にほんご → 日本語」の語は無いので、`nihongo` では当たらない
   - `<Tab>` の候補は、バッファ内で Migemo に一致した文字列を ripgrep で集めたもの。ローマ字が 3 文字以上のときだけ出る
   - 整形は保存時に conform.nvim が `markdownlint-cli2 --fix` と `markdown-toc` を順に掛ける。`#動作確認` は MD018 (見出しの `#` の後の空白) の違反
   - IME 連携は ibus-daemon が動いているセッションで起動したときだけ有効になる。ログインし直した後の端末で起動する
   - コンテナでは ibus-daemon を `--panel disable` で起動して、`<C-j>` で `ibus engine` が `anthy` に、`<Esc>` で `xkb:us::eng` に変わるのを確かめた。アイコンの見た目は確かめていない

   </details>

### Windows 11 に導入する (1 度だけ)

- Windows 11 に scoop で外部コマンド・Neovim・zenhan を入れ、この設定を `%LOCALAPPDATA%\nvim` に clone して初回起動する
- 管理者ではない PowerShell で貼る。Windows PowerShell 5.1 でも PowerShell 7 でもよい
- この節の手順は、Windows 11 Pro の実機で Windows PowerShell 5.1 に貼る形で通した (scoop が入っていたので手順 2 は飛ばした。範囲は[対象と検証環境](#対象と検証環境))

1. scoop が入っているか確かめる。

   ```powershell
   Get-Command scoop -ErrorAction SilentlyContinue
   ```

   - `scoop` の行が出れば、この節の手順 2 は飛ばす
   - 何も出なければ、この節の手順 2 で入れる

1. scoop が未導入のときだけ、scoop を入れる。

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
   ```

   - `Scoop was installed successfully!` と出ればよい
   - scoop は `%USERPROFILE%\scoop` に入り、管理者権限は要らない

1. git が無ければ入れ、scoop に `extras` のバケットを足す。

   ```powershell
   if (-not (Get-Command git -ErrorAction SilentlyContinue)) { scoop install git }
   scoop bucket add extras
   ```

   - Git for Windows などで git がすでにあれば、`scoop install git` は飛ばされる
   - バケットの追加に git が要る。lazygit は `extras` にある

1. 既存の Neovim の設定とデータがあれば、`.bak` を付けて退避する。

   ```powershell
   foreach ($d in "$env:LOCALAPPDATA\nvim", "$env:LOCALAPPDATA\nvim-data") {
     if (Test-Path "$d.bak") { Write-Warning "$d.bak がすでにある" } elseif (Test-Path $d) { Move-Item $d "$d.bak"; "moved: $d" }
   }
   ```

   - 退避したものは `moved: …` と出る。何も出なければ、退避するものは無かった
   - **注意**: `.bak` がすでにあると退避しない (警告が出る)。古い `.bak` を片付けてから、この手順を貼り直す
   - `nvim` は設定、`nvim-data` はプラグイン・Mason のツール・undo など

1. この設定を `%LOCALAPPDATA%\nvim` に clone する。

   ```powershell
   if (-not (Test-Path "$env:LOCALAPPDATA\nvim\init.lua")) { git clone https://github.com/ryo-aoki-pc/LazyVimStarter.git "$env:LOCALAPPDATA\nvim" }
   git -C "$env:LOCALAPPDATA\nvim" branch --show-current
   ```

   - `custom` と出ればよい
   - すでに clone してあれば、`git clone` は飛ばされる

1. 外部コマンドと Neovim・zenhan・lazygit を scoop で入れる。

   ```powershell
   scoop install neovim ripgrep fd gcc nodejs zenhan lazygit
   ```

   - `zenhan` は IME 連携に使う。無ければ IME 連携だけが静かに無効になる
   - `lazygit` は任意 (無ければ `<leader>gg` が定義されないだけ)
   - 入っているものは、何も出さずに飛ばされる (scoop は複数を並べると `already installed` を出さない)

   <details>
   <summary>補足: Windows の外部コマンド</summary>

   - `zenhan` / `neovim` / `ripgrep` / `fd` / `gcc` / `nodejs` は scoop の `main` バケット、`lazygit` は `extras` にある (バケットの定義で確認)
   - `curl` と `tar` は Windows 11 が `C:\Windows\System32` に同梱している
   - `gzip` と `unzip` は要らない。Mason は Windows では zip を PowerShell の `Expand-Archive` で、`.tar.gz` を同梱の `tar` で展開する。この設定で入る 12 個は、どちらかか、展開の要らない exe・npm で済む
   - `:checkhealth mason` の `unzip` / `gzip` / `wget` の WARNING は無視してよい
   - C コンパイラは `gcc` が PATH にあれば、LazyVim が見つけて `CC` に設定する
   - scoop を使わないなら `winget install --id=BrechtSanders.WinLibs.POSIX.UCRT` が手軽。Visual Studio Build Tools の `cl.exe` も自動で見つかる
   - `zenhan` の代わりに `im-select` でもよい (scoop のバケットには無い)
   - シェルは `pwsh` (PowerShell 7) があればそれを、無ければ `powershell` を使う (`lua/config/options.lua`)
   - **Microsoft Store 版の PowerShell 7 は、PATH の上ではアプリ実行エイリアス (中身の無いファイル) で、Neovim は実行ファイルと判定しない**。pwsh の中から起動した nvim でだけ `pwsh` になり、エクスプローラーやスタートメニューから起動した Neovide などでは `powershell` (5.1) になる。どちらでも動く
   - どこから起動しても `pwsh` にしたいなら、`scoop install pwsh` など、PATH にエイリアスではない `pwsh.exe` が載る入れ方にする
   - Neovide を使うなら **Neovide 0.16 以上 + Neovim 0.12 以上**にする。それより古いと IME の未確定文字列が確定まで表示されない

   </details>

1. 入ったか確かめ、フォントを入れる。

   ```powershell
   nvim --version | Select-Object -First 1
   Get-Command rg, fd, gcc, node, npm, zenhan, lazygit | Format-Table Name, Source
   ```

   - `NVIM v0.12.…` と出ればよい (0.12 以上が要る)
   - 7 つのコマンドの場所が並ぶ
   - フォントは [HackGen のリリース](https://github.com/yuru7/HackGen/releases)から `HackGen_NF_v….zip` を落として展開し、`HackGenConsoleNF-*.ttf` を右クリック →「インストール」で入れる
   - 端末 (Windows Terminal / WezTerm など) のフォントも HackGen Console NF にする

1. プラグインを入れ、`lazy-lock.json` の版に揃える。

   ```powershell
   nvim --headless +qa
   git -C "$env:LOCALAPPDATA\nvim" checkout -- lazy-lock.json
   nvim --headless "+Lazy! restore" +qa
   git -C "$env:LOCALAPPDATA\nvim" status --short
   ```

   - 数分かかる。Mason と treesitter の中断のメッセージは出てよい
   - 最後の `git status --short` が何も出さなければ、`lazy-lock.json` の版に揃っている
   - 理由は [AlmaLinux 導入の手順 16](#almalinux-10-に導入する-1-度だけ) の補足と同じ
   - **次の手順は、プロンプトが戻ってから貼る**

1. 試験用の Markdown を開いて、treesitter と Mason の導入を待つ。

   ```powershell
   Set-Content -Path "$env:TEMP\lazyvim-check.md" -Value '#動作確認', '', '日本語の検索を試す。' -Encoding UTF8
   nvim "$env:TEMP\lazyvim-check.md"
   ```

   - `:Mason` を開き、Installed が 12 個になり、導入中のものが無くなるまで待つ (`q` で閉じる)
   - 待ったら `:qa` で閉じる
   - **次の手順は、`:qa` で閉じてから貼る** (続けて貼ると Neovim への入力として食われる)

1. 外部コマンドと Mason のツールが揃ったかを、`checkhealth` で確かめる。

   ```powershell
   nvim --headless "+Lazy! load mason.nvim luamigemo" "+checkhealth lazyvim luamigemo" "+w! $env:TEMP\lazyvim-health.txt" +qa
   Select-String -Path "$env:TEMP\lazyvim-health.txt" -Pattern 'ERROR|WARNING'
   ```

   - `` WARNING `fzf` is not installed `` の 1 行だけならよい (無視してよい)
   - `ERROR` が出たら[注意点](#注意点)

1. 試験用の Markdown を開き、日本語検索・整形・IME 連携を確かめる。

   ```powershell
   nvim "$env:TEMP\lazyvim-check.md"
   ```

   - 確かめることは [AlmaLinux 導入の手順 19](#almalinux-10-に導入する-1-度だけ) と同じ (`/kensaku`・`<Tab>`・`:w`・`<C-j>`・アイコン)
   - `:lua =vim.fn.executable("zenhan")` が `1` なら IME 連携が有効 (`0` でもほかは動く)
   - OS 側で IME を切り替えても、Neovim は気付けない (lualine の `あ` / `A` がずれることがある。[README](../README.md#日本語入力検索))
   - `:qa!` で閉じる。これで導入は終わり

### ほかのマシンの変更を取り込む (繰り返し)

- 別のマシンで push した設定の変更と `lazy-lock.json` を取り込み、プラグインをその版に揃える
- AlmaLinux 10 はこの節の手順 1、Windows 11 はこの節の手順 2 を貼る
- Mason のツールや treesitter のパーサーが増えたときは、次に Neovim でファイルを開いたときに入る

1. AlmaLinux 10 では、設定を最新にしてプラグインを揃える。

   ```bash
   git -C ~/.config/nvim pull --ff-only && nvim --headless "+Lazy! restore" +qa
   git -C ~/.config/nvim status --short
   ```

   - `git status --short` が何も出さなければ、`lazy-lock.json` の版に揃っている
   - `pull` が `Not possible to fast-forward` で止まったら、このマシンに push していないコミットがある。先に push するか、`git -C ~/.config/nvim log --oneline '@{u}..'` で中身を見る
   - `pull` が `Your local changes to the following files would be overwritten by merge:` で `lazy-lock.json` を挙げて止まったら、このマシンで lock が書き換わっている。`:Lazy update` の結果として残すのでなければ、`git -C ~/.config/nvim checkout -- lazy-lock.json` で戻してから、この手順を貼り直す

1. Windows 11 では、(この節の手順 1 の代わりに) 設定を最新にしてプラグインを揃える。

   ```powershell
   git -C "$env:LOCALAPPDATA\nvim" pull --ff-only; if ($?) { nvim --headless "+Lazy! restore" +qa }
   git -C "$env:LOCALAPPDATA\nvim" status --short
   ```

   - `git status --short` が何も出さなければ、`lazy-lock.json` の版に揃っている
   - `pull` が `Not possible to fast-forward` で止まったときは、`restore` は走らず、`git status --short` も何も出さない。このマシンに push していないコミットがある。先に push するか、`git -C "$env:LOCALAPPDATA\nvim" log --oneline '@{u}..'` で中身を見る
   - `pull` が `Your local changes to the following files would be overwritten by merge:` で `lazy-lock.json` を挙げて止まったら、このマシンで lock が書き換わっている。`:Lazy update` の結果として残すのでなければ、`git -C "$env:LOCALAPPDATA\nvim" checkout -- lazy-lock.json` で戻してから、この手順を貼り直す

---

## カーソル色を tmux で効かせる (任意)

- 挿入モードのカーソル色も IME の状態で変わる。ただし tmux 越しでは既定では効かないので、tmux の設定に 1 行足す
- AlmaLinux 10 で tmux を使うときだけ行う。無くても害は無い
- `tmux-256color` には `Cs` / `Cr` が無く、Neovim がカーソル色の OSC 12 を出さないため

1. tmux の設定ファイルに `terminal-overrides` を 1 行足す。

   ```bash
   mkdir -p ~/.config/tmux
   grep -qF 'Cs=\E]12' ~/.config/tmux/tmux.conf 2>/dev/null || cat >> ~/.config/tmux/tmux.conf <<'EOF'
   set -ga terminal-overrides ',*:Cs=\E]12;%p1%s\007:Cr=\E]112\007'
   EOF
   ```

   - すでに書いてあれば足さない
   - **注意**: `~/.tmux.conf` があると、tmux は `~/.config/tmux/tmux.conf` を読まない。そのときは、この 1 行を `~/.tmux.conf` に書く

1. tmux の中で、設定を読み直して確かめる。

   ```bash
   tmux source-file ~/.config/tmux/tmux.conf
   tmux show-options -g terminal-overrides | grep -F 'Cs='
   ```

   - `terminal-overrides[0] "*:Cs=\\E]12;%p1%s\\007:Cr=\\E]112\\007"` のような行が出ればよい
   - `-ga` は足すたびに同じ値を増やすので、起動時と読み直しの分で 2 行出ることがある。害は無い
   - Neovim を起動し直すと、挿入モードで `<C-j>` を押したときにカーソルの色が変わる

---

## 更新

- Neovim・外部コマンド・プラグインを上げる。設定そのものの取り込みは[ほかのマシンの変更を取り込む](#ほかのマシンの変更を取り込む-繰り返し)
- AlmaLinux 10 はこの節の手順 1・3、Windows 11 はこの節の手順 2・4 を貼る
- プラグインを上げると `lazy-lock.json` が変わる。確かめてからコミットし、push する ([README の lazy-lock.json の運用](../README.md#lazy-lockjson-の運用))

1. AlmaLinux 10 では、Homebrew で入れたものを上げる。

   ```bash
   brew upgrade neovim lazygit
   brew upgrade --cask font-hackgen-nerd
   nvim --version | head -1
   ```

   - 最新なら `Warning: neovim 0.12.5_1 already installed` のように出て、何も上げない
   - dnf で入れたもの (git・ripgrep・node など) は、OS の更新 (`sudo dnf upgrade`) で上がる

1. Windows 11 では、(この節の手順 1 の代わりに) scoop で入れたものを上げる。

   ```powershell
   scoop update
   scoop update neovim ripgrep fd gcc nodejs zenhan lazygit
   nvim --version | Select-Object -First 1
   ```

   - 最新なら `latest version` と出る

1. AlmaLinux 10 では、プラグインを上げて `lazy-lock.json` の差分を見る。

   ```bash
   nvim --headless "+Lazy! update" +qa
   git -C ~/.config/nvim diff --stat
   ```

   - `lazy-lock.json` だけが変わっていればよい
   - 上げた後は、Neovim を起動して使えることを確かめてから、`lazy-lock.json` をコミットして push する

1. Windows 11 では、(この節の手順 3 の代わりに) プラグインを上げて差分を見る。

   ```powershell
   nvim --headless "+Lazy! update" +qa
   git -C "$env:LOCALAPPDATA\nvim" diff --stat
   ```

   - `lazy-lock.json` だけが変わっていればよい

---

## ロールバック

- この設定とプラグインを消し、[AlmaLinux 導入の手順 5](#almalinux-10-に導入する-1-度だけ) / [Windows 導入の手順 4](#windows-11-に導入する-1-度だけ) で退避したものを戻す
- AlmaLinux 10 はこの節の手順 1〜4、Windows 11 はこの節の手順 5〜7 を、上から順に貼る
- dnf / scoop で入れた共通のコマンド (git・ripgrep・node など) と Homebrew 本体は、ほかでも使うので残す
- Windows 11 の手順 7 (scoop のアンインストール) は実行していない。手順 5・6 は、設定の置き場所を差し替えた環境で通した

> [!CAUTION]
> **この節の手順 2 と手順 6 で、設定のディレクトリごと消える。push していない変更は取り戻せない**。手順 1 と手順 5 で確かめてから貼る。

1. AlmaLinux 10 で、設定に push していない変更が無いか確かめる。

   ```bash
   git -C ~/.config/nvim status --short
   git -C ~/.config/nvim log --oneline '@{u}..'
   ```

   - 2 つとも何も出なければよい
   - 何か出たら、push するか別の場所に写してから、この手順を貼り直す
   - **次の手順は、何も出ないことを確かめてから貼る**

1. AlmaLinux 10 で、この設定とプラグインを消し、退避したものを戻す (取り戻せない)。

   ```bash
   for d in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim; do
     rm -rf "${d}"
     [ ! -e "${d}.bak" ] || mv -vT "${d}.bak" "${d}"
   done
   ```

   - 戻したものは `renamed '…/nvim.bak' -> '…/nvim'` と出る。何も出なければ、戻すものは無かった
   - Mason のツールと treesitter のパーサーも、`~/.local/share/nvim` と一緒に消える

1. AlmaLinux 10 で、入力ソースと Anthy のキーを既定に戻す。

   ```bash
   export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
   gsettings reset org.gnome.desktop.input-sources sources
   gsettings reset org.freedesktop.ibus.engine.anthy.shortcut default
   gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | grep -o "'on_off': <\[[^]]*\]>"
   ```

   - `'on_off': <['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J']>` と出ればよい
   - 入力ソースは既定 (空) に戻る。導入の前の値に戻すなら、[AlmaLinux 導入の手順 13](#almalinux-10-に導入する-1-度だけ) の最初の行に出た値を `gsettings set` で書く

1. AlmaLinux 10 で、Homebrew で入れたものも消すときだけ、消す。

   ```bash
   brew uninstall neovim lazygit
   brew uninstall --cask font-hackgen-nerd
   brew autoremove
   ```

   - `brew uninstall` が、Neovim の依存 7 つ (`luajit` など) のうち、ほかに使われていないものも消す (`==> Autoremoving 7 unneeded formulae:`)
   - `brew autoremove` は、それでも残った不要な依存を消す (検証では何も残っていなかった)
   - ibus-anthy は日本語入力そのものなので残す

1. Windows 11 では、(この節の手順 1 の代わりに) push していない変更が無いか確かめる。

   ```powershell
   git -C "$env:LOCALAPPDATA\nvim" status --short
   git -C "$env:LOCALAPPDATA\nvim" log --oneline '@{u}..'
   ```

   - 2 つとも何も出なければよい
   - **次の手順は、何も出ないことを確かめてから貼る**

1. Windows 11 では、(この節の手順 2 の代わりに) 設定を消して退避分を戻す (取り戻せない)。

   ```powershell
   foreach ($d in "$env:LOCALAPPDATA\nvim", "$env:LOCALAPPDATA\nvim-data") {
     if (Test-Path $d) { Remove-Item -Recurse -Force $d }
     if (Test-Path "$d.bak") { Move-Item "$d.bak" $d; "restored: $d" }
   }
   ```

   - 戻したものは `restored: …` と出る

1. Windows 11 で、scoop で入れたものも消すときだけ、消す。

   ```powershell
   scoop uninstall neovim zenhan lazygit
   ```

   - ripgrep・fd・gcc・nodejs はほかでも使うので残す。消すなら同じコマンドに足す

---

## 補足

### 対象と検証環境

- **目的**: 新しいマシンで、この Neovim 設定 (日本語の入力・検索と Markdown 執筆の強化) を動かす。設定そのものの説明は [README](../README.md)
- **進め方**: 外部コマンドを先に揃え、この設定を clone し、プラグインを `lazy-lock.json` の版に揃えてから初回起動する
  - 変数は無い。読者が書き換える値も無い
  - AlmaLinux 10 は dnf + EPEL と Homebrew、Windows 11 は scoop で入れる
- **状態**:
  - **AlmaLinux 10 の導入は、x86_64 のコンテナでのみ通した (2026-09-28)。実機では、この形では通していない**
    - クラウドホスト上の Docker の `almalinux:10` (AlmaLinux 10.2) に、sudo のできる一般ユーザーを作り、端末 (tmux) に**この文書のコードブロックをそのまま貼って**通した
    - 通したもの: AlmaLinux 導入の手順 1〜19、取り込みの手順 1、tmux の節、更新の手順 1・3、ロールバックの手順 1〜4
    - GNOME の代わりに、セッションバス (`dbus-daemon --session`) と dconf で `gsettings` を動かした。IME 連携は ibus-daemon を `--panel disable` で起動して確かめた
    - 確かめたこと:
      - 入るパッケージと版、EPEL の鍵、`brew` の確認、`fc-match`
      - Anthy のキーの置き換え (ほかのキーが残ること)
      - `lazy-lock.json` の版に揃うこと、Mason の 12 個、`checkhealth` の ERROR が 0 件
      - `/kensaku` の検索、保存時の整形、`<C-j>` での `anthy` ↔ `xkb:us::eng` と lualine の `あ` / `A`
    - **確かめていないこと**:
      - treesitter のパーサーの導入 (検証環境のプロキシが github.com の archive を 403 で拒んだ)
      - GNOME の画面・Super+Space・アイコンの見た目・ログインし直しての ibus の読み直し
      - aarch64
      - PR #26 で入った、カーソルのすぐ下の `あ` / `A` の表示 (検証した設定は、その前の 9c4e8d9)
    - 検証の都合で変えたこと (手順には含めない): sudo をパスワード無しにし、プロキシの環境変数と CA を渡した ([付録](#付録-コンテナでの検証記録-2026-09-28))
  - **Windows 11 は、実機 (Windows 11 Pro 10.0.26200、x64) で通した (2026-09-29)。設定とデータの置き場所は、一時的な場所に差し替えた**
    - `LOCALAPPDATA` と `TEMP` を差し替え、PATH をレジストリの値から組み立て直した Windows PowerShell 5.1 に、**この文書のコードブロックをそのまま渡して**通した ([付録](#付録-windows-11-の実機での検証記録-2026-09-29))
    - 通したもの: Windows 導入の手順 1・3〜11 (scoop が入っていたので手順 2 は飛ばした)、取り込みの手順 2、更新の手順 2・4、ロールバックの手順 5・6
    - 確かめたこと:
      - `lazy-lock.json` の版に揃うこと、Mason の 12 個、treesitter のパーサー 31 個とハイライト、`checkhealth` の ERROR が 0 件
      - `/kensaku` の検索、`<Tab>` の候補、保存時の整形、`<C-j>` と lualine の `あ` / `A`、カーソルのすぐ下の表示、検索の sticky
      - 取り込みの手順 2 を、変更がある状態・push していないコミットがある状態・`lazy-lock.json` が書き換わった状態で通すこと
      - Neovide 0.16.2 の画面での、未確定文字列 (下線・変換中の文節の反転・カーソルの位置)・カーソルのすぐ下の表示・lualine の `あ` / `A` (未確定文字列は、Neovide が IME から受け取ったときと同じ引数でハンドラを呼んで描かせた)
    - **確かめていないこと**:
      - 本物の IME の切り替え (zenhan は、呼び出しを記録するモックに差し替えた。本物は前面のウィンドウの IME を切り替えるため)
      - Neovide に本物の IME で打ったとき、Neovide がハンドラを呼ぶこと (呼び出しの形は Neovide 0.16.2 のソースで確かめた)
      - scoop の導入 (Windows 導入の手順 2) と、ロールバックの手順 7
  - 以前の版の状態行は「AlmaLinux 10 の使い捨てコンテナで手順を頭から流して検証済み」だった。本書はシナリオに分けてコマンドも変えたので、上の記録で置き換える

| 項目 | AlmaLinux 10 | Windows 11 |
|---|---|---|
| 検証 | x86_64 のコンテナ (AlmaLinux 10.2) で通した | 実機 (Windows 11 Pro) で、置き場所を差し替えて通した |
| パッケージマネージャ | dnf + EPEL、Neovim・lazygit・フォントは Homebrew (7.0.7) | scoop |
| Neovim | Homebrew の `neovim` (0.12.5) | scoop の `neovim` (0.12.5) |
| IME | ibus 1.5.32 + ibus-anthy 1.5.17 (`busctl` / `gdbus` で制御) | zenhan 0.0.1 (任意。検証ではモック) |
| フォント | Homebrew の cask `font-hackgen-nerd` (2.10.0) | リリースの zip から手で入れる |
| 設定の置き場所 | `~/.config/nvim` | `%LOCALAPPDATA%\nvim` |

> [!NOTE]
> - 本書には変数が無い。設定の置き場所と clone 元の URL は、Neovim と GitHub が決める固定の値なので、コマンドに直接書いてある
> - 途中で作る値は `ANTHY_SHORTCUT` だけ ([AlmaLinux 導入の手順 14](#almalinux-10-に導入する-1-度だけ) で作り、手順 15 で使う)
> - 出力例の中のユーザーのホームは `…` で省いてある。パスワード・鍵・トークンは扱わない

### 実施前の状態

| 項目 | 状態 |
|---|---|
| OS | AlmaLinux 10 + GNOME (Wayland) / Windows 11 |
| ユーザー | AlmaLinux 10 は `sudo` のできる一般ユーザーで、GNOME にログインしている。Windows 11 は一般ユーザー |
| ネットワーク | github.com・Homebrew・npm・scoop に届く (初回のプラグイン・Mason・treesitter の取得に要る) |
| Neovim の設定 | 無い、または退避してよい (AlmaLinux 導入の手順 5 / Windows 導入の手順 4 で `.bak` にする) |
| Homebrew / scoop | 未導入でも導入済みでもよい (手順の中で判定する) |
| 入力ソース | 何でもよい (AlmaLinux 導入の手順 13 で `us` と `anthy` の 2 つに置き換える) |

### 必要なもの一覧

| 依存 | 用途 | 必須? |
| --- | --- | --- |
| [Neovim](https://neovim.io/) 0.12 以上 | 本体。LazyVim の下限は 0.11.2 だが、`lazy-lock.json` の nvim-treesitter が 0.12 を要る | 必須 ([AlmaLinux 導入の手順 11](#almalinux-10-に導入する-1-度だけ) の補足) |
| git | lazy.nvim の bootstrap、プラグインの取得・更新、git 系ピッカー | 必須 |
| PowerShell (pwsh 推奨) | Windows の `shell`。外部コマンドと端末が全部これを通る | Windows で必須 |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | grep ピッカーと `grepprg`、`/` の `<Tab>` で出す Migemo の候補 | 必須 |
| [fd](https://github.com/sharkdp/fd) | ファイルピッカーと explorer | Windows で必須 / Linux では推奨 |
| C コンパイラ (gcc または MSVC の cl) | treesitter のパーサーのビルド | 必須 |
| tree-sitter CLI | treesitter のパーサーのビルド。PATH に無ければ LazyVim が Mason で入れる | 必須 (自動で入る) |
| curl / tar / gzip / unzip | treesitter と Mason の取得・展開 | 必須 (Windows 11 は同梱の curl と tar だけでよい。[Windows 導入の手順 6](#windows-11-に導入する-1-度だけ) の補足) |
| [Node.js](https://nodejs.org/) (node + npm) | Mason が npm で入れる LSP・整形ツール | 必須 |
| Nerd Font ([HackGen Console NF](https://github.com/yuru7/HackGen)) | アイコン表示と `guifont` | 実質必須 (無いと記号が豆腐になる) |
| ibus + ibus-anthy、`busctl` か `gdbus` | 日本語入力 (Linux)。global engine を切り替える | Linux で必須 |
| [zenhan](https://github.com/iuchim/zenhan) または im-select | 日本語入力 (Windows) | 任意 (無ければ IME 連携のみ無効) |
| [Neovide](https://neovide.dev/) 0.16 以上 | GUI クライアント。IME の未確定文字列の表示には Neovim 0.12 以上も要る | 任意 (端末で使うなら不要) |
| lazygit | `<leader>gg` | 任意 (無ければキーマップが定義されないだけ) |
| ネットワーク | 初回のプラグイン取得、Mason、treesitter のパーサー | 初回のみ必須 |

- **不要なもの**: fzf (ピッカーは snacks.nvim の Lua 実装。`:checkhealth lazyvim` が警告を出すが機能には影響しない)、telescope とその C ビルド、make、Python、Deno、win32yank (Neovim の Windows ビルドに同梱済み)
- **markdown-preview.nvim**: ビルド時にプリビルドのバイナリを落とす。Linux では x86_64 (と i686) の分しか無い
  - aarch64 では node で動かす形になり、プラグインの `app` で `npm install` が要る (プラグインのコードから読んだもので、試していない)

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
- **初回は headless で入れて、`lazy-lock.json` を戻してから restore する**: 初回の導入が lock を書き換えるため ([AlmaLinux 導入の手順 16](#almalinux-10-に導入する-1-度だけ) の補足)
  - 画面を開く前に揃えるので、初回起動からほかのマシンと同じ版で動く
- **入力ソースは `us` と `anthy` に固定する**: IME 連携が英数を `xkb:us::eng` に固定しているため ([AlmaLinux 導入の手順 13](#almalinux-10-に導入する-1-度だけ) の補足)
- **フォントは Linux では Homebrew の cask にする**: zip を落として `~/.local/share/fonts` に置く手作業が 1 行になり、`brew upgrade --cask` で上がる。Windows には同じ手段が無いので手で入れる
- **動作確認は試験用のファイルで行う**: `/tmp` の Markdown 1 つで、LSP の導入の引き金・日本語検索・整形の 3 つを確かめられる

### 完了時点の状態

| 場所 | 中身 |
|---|---|
| `~/.config/nvim` (`%LOCALAPPDATA%\nvim`) | このリポジトリの clone (`custom` ブランチ) |
| `~/.local/share/nvim/lazy` | プラグイン 38 個 (`lazy-lock.json` の版)。コンテナで 189 MB |
| `~/.local/share/nvim/mason` | Mason のツール 12 個。コンテナで 279 MB |
| `~/.local/share/nvim/site/parser` | treesitter のパーサー (初回起動で入る) |
| `~/.local/share/fonts` | HackGen Console NF と HackGen35 Console NF (Linux) |
| `~/.bashrc` | `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"` の 1 行 (Linux) |
| `org.gnome.desktop.input-sources sources` | `[('xkb', 'us'), ('ibus', 'anthy')]` (Linux) |
| `org.freedesktop.ibus.engine.anthy.shortcut default` | `on_off` が `['Zenkaku_Hankaku']` だけ (Linux) |
| `*.bak` | 退避した以前の設定とデータ (あった場合だけ) |

- Windows のプラグインと Mason のツールは `%LOCALAPPDATA%\nvim-data` に入る

### 注意点

- **一部の Mason のツールだけが入らない (`stylua` など)**: `unzip` が無い
  - Mason は zip で配布されるツールの展開に `unzip` を使い、無いと**そのツールだけ**が静かに失敗する
  - `:Mason` で状態を見て、`sudo dnf install unzip` の後に入れ直す
- **npm で入るツールだけが入らない (`markdownlint-cli2` など)**: node と npm が無いか、npm が registry に届かない
  - `~/.local/state/nvim/mason.log` に npm のエラーが残る。検証環境では、プロキシの CA を node に渡すまで `SELF_SIGNED_CERT_IN_CHAIN` で失敗した
- **treesitter のハイライトが効かない**: C コンパイラか tree-sitter CLI が見つかっていない
  - `:checkhealth lazyvim` の `LazyVim nvim-treesitter` の節で `C compiler` と `tree-sitter (CLI)` を見る
  - Windows で `gcc` を入れた直後は PATH が反映されていないことがある。端末を開き直してから `nvim` を起動する
- **ファイルピッカーが空のまま**: `fd` も `rg` も無い。Linux には `find` へのフォールバックがあるが、Windows には無い
- **保存しても Markdown が整形されない / lint が出ない**: `markdownlint-cli2` と `markdown-toc` は npm のパッケージ
  - node を入れ替えたり消したりすると、Mason で入れたものごと壊れる
  - `:Mason` で状態を見て、`:MasonInstall markdownlint-cli2 markdown-toc` で入れ直す
- **Windows で `<leader>cp` のプレビューが開かない (`node:internal/modules/cjs/loader` のエラー)**: markdown-preview.nvim のバイナリ (`app\bin\markdown-preview-win.exe`) が入っていない
  - この設定の build は、Windows では `install.cmd` を `cmd.exe` で実行する (`shell` の PowerShell からは、カレントディレクトリの `install.cmd` を実行できないため)。この形になる前に入れたマシンでは、バイナリが入っていない
  - Neovim で `:Lazy build markdown-preview.nvim` を実行して入れ直す。20 秒ほどかかる
- **`/` からの日本語検索が効かない**: `:checkhealth luamigemo` で、同梱の辞書と LuaJIT を確かめる
  - ローマ字として読めない入力 (`search` のような英単語、空白や記号を含むもの) は、わざと変換しない
  - まず `/kensaku` のような純粋なローマ字で試す
  - `<Tab>` で候補が出ないときは、ローマ字が 3 文字以上か、`rg` が PATH にあるかを確かめる (候補の照合は ripgrep に任せている)
- **アイコンが豆腐 (□) になる**: 端末のフォントが Nerd Font になっていない。`guifont` は GUI クライアント専用で、端末には効かない
- **全角記号を含む行の桁がずれる**: Neovim の `ambiwidth` と、端末の East Asian Ambiguous の幅の設定が食い違っている
  - この設定は両方を narrow 側 (`single` / `treat_east_asian_ambiguous_width_as_wide=false`) に揃えてある。端末側だけを wide にしない
- **`lazy-lock.json` が勝手に変わる**: `:Lazy sync` / `:Lazy update` は最新に上げる。揃えるだけなら `:Lazy restore`
  - 初めてのマシンの初回起動でも変わる ([AlmaLinux 導入の手順 16](#almalinux-10-に導入する-1-度だけ) の補足)
- **日本語が一切入力できない (Linux)**: ibus のエンジン自体が起動に失敗している可能性がある
  - Neovim の中だけでなく、OS 全体で打てなくなるのが特徴
  - ibus はエンジンの起動に失敗しても黙って英数のままになる。`ibus engine` は `anthy` を返すのに変換だけが効かない、という見え方になる
  - エンジンのプロセスはフォーカスしたときに起動するので、`ps` に `ibus-engine-anthy` が居ないこと自体は異常の証拠にならない
  - まずエンジンを直接起動してみる。エンジンの定義 (XML) が出れば起動できている

  ```bash
  /usr/libexec/ibus-engine-anthy --xml | head -3
  ```

- **`ModuleNotFoundError: No module named 'gi'` が出る**: `python3` が、システム (`/usr/bin/python3`) ではなく Homebrew のものになっている
  - `/usr/libexec/ibus-engine-anthy` は `exec python3 …` と PATH 頼りで起動する。Homebrew の python には PyGObject (`gi`) が無い
  - `brew` が `python@3.x` をほかの formula の依存として link すると、PATH の先頭に入った瞬間にエンジンが死ぬ
  - `brew info --json=v2 python@3.14` の `installed_on_request` が `false` (依存として入っただけ) なら unlink してよい
  - 依存する formula は shebang に Cellar / opt の絶対パスを持つので影響を受けない
  - **`brew upgrade` で link し直されると同じ症状が出る**。そのときはもう一度 unlink する

  ```bash
  which python3                 # /home/linuxbrew/... ならこれが原因
  brew unlink python@3.14       # brew の bin から python3 の symlink を外す
  ibus restart
  ```

### 参照

- [LazyVim のインストール](https://lazyvim.github.io/installation): 要求される外部コマンドと初回起動の流れ
- [lazy.nvim](https://lazy.folke.io/): `:Lazy restore` と `lazy-lock.json` の扱い
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux): `/home/linuxbrew/.linuxbrew` に入れる理由とボトルの条件
- [scoop](https://scoop.sh/): 管理者権限なしで `%USERPROFILE%\scoop` に入れる
- [luamigemo](https://github.com/delphinus/luamigemo): ローマ字検索 (Migemo) の純 Lua 実装。同梱の辞書のライセンスもここ
- [ibus-anthy](https://github.com/ibus/ibus-anthy): `on_off` などのキー割り当て
- [HackGen](https://github.com/yuru7/HackGen): フォントのリリース
- [README](../README.md): この設定で何ができるか、IME 連携の設計と運用上の注意

### 付録: コンテナでの検証記録 (2026-09-28)

- **環境**: x86_64 のクラウドホスト上の Docker 29.3.1、イメージ `quay.io/almalinuxorg/almalinux:10` (AlmaLinux 10.2)
  - ホストのネットワークを使い、プロキシの環境変数と CA をコンテナに渡した。sudo の `env_keep` にプロキシの変数を足し、node には `NODE_EXTRA_CA_CERTS` で CA を渡した
  - 一般ユーザー (uid 1000) を作り、sudo をパスワード無しにした
  - GNOME の代わりに `sudo`・`tmux`・`dbus-daemon`・`dconf`・`gsettings-desktop-schemas`・`fontconfig`・`ibus` を入れ、`dbus-daemon --session --address=unix:path=/run/user/1000/bus` を起動した
  - ホストの tmux 3.4 から `docker exec -it … bash -i` を開き、各ブロックをブラケットペーストで貼った (`enable-bracketed-paste` は on)。コンテナの中の tmux 3.3a は `capture-pane -p` で落ちたので、操作には使わなかった
- **探索の実行**: 最初に手順の候補を 1 つのコンテナで流し、出力を見てから文書を書いた。そこで分かったことは本文に入れた
  - `rpm -q npm` は `package npm is not installed` になる (パッケージ名は `nodejs-npm`)
  - `brew install neovim lazygit` が `[y/n]` を聞く
  - `nvim --version` だけで `~/.local/state/nvim` ができる
  - 初回の導入の後に `lazy-lock.json` の 6 行が変わる。`restore` を続けても戻らず、git で戻してから `restore` し直すと揃う
  - `checkhealth lazyvim` の前に mason.nvim を読み込まないと、`` ERROR `tree-sitter (CLI)` is not installed `` が出る
  - 同じ状態から `nvim --headless "+Lazy! sync" +qa` を実行すると、同じ 6 行が変わった
  - 最初は npm にプロキシの CA が渡っておらず、npm で入る 5 個が `SELF_SIGNED_CERT_IN_CHAIN` で入らなかった。CA を足して起動し直すと、足りないものが自動で入った
- **本番の実行**: 新しいコンテナで、この文書から取り出したブロックを順に貼った
  - clone した設定は 9c4e8d9 (PR #25 の時点)。PR #26 (カーソルのすぐ下の `あ` / `A` の表示) は、この検証の後に `custom` に入った
  - 通したのは、AlmaLinux 導入の手順 1〜19、取り込みの手順 1、tmux の節の手順 1・2、更新の手順 1・3、ロールバックの手順 1〜4
  - 「ログアウトしてログインし直す」の代わりに、ibus-daemon を `--panel disable` で起動し、シェルを開き直した
- **dnf** (AlmaLinux 導入の手順 3): 最小構成のイメージで、101 個を入れて 4 個を更新した
  - 主な版: git 2.52.0、ripgrep 14.1.1、fd-find 10.4.2、gcc 14.3.1、nodejs 22.23.2、nodejs-npm 10.9.8、ibus-anthy 1.5.17
  - EPEL の鍵の確認 (`Importing GPG key 0xE37ED158` と fingerprint) は、この手順で出た
- **Homebrew** (AlmaLinux 導入の手順 8〜12): Homebrew 7.0.7、neovim 0.12.5_1、lazygit 0.65.1、font-hackgen-nerd 2.10.0
  - インストーラは `Checking for sudo access` → 導入先の一覧 → `Press RETURN/ENTER to continue` の順に出た
  - `brew install neovim lazygit` は `[y/n]` を聞き、`brew install --cask font-hackgen-nerd` は聞かなかった
- **Anthy** (AlmaLinux 導入の手順 13〜15): 入力ソースは `@a(ss) []` から `[('xkb', 'us'), ('ibus', 'anthy')]` になった
  - `on_off` は `['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J']` から `['Zenkaku_Hankaku']` になり、キーは 46 個のまま (探索の実行で数えた)
- **プラグイン** (AlmaLinux 導入の手順 16): 38 個が入り、最後の `git status --short` は何も出さなかった
  - 探索の実行で変わった 6 個は、SchemaStore.nvim・gitsigns.nvim・mason-lspconfig.nvim・mini.icons・nvim-lspconfig・nvim-treesitter。記録の版はどれもリポジトリにあり、最新の版が入っていた
  - lazy.nvim の `lua/lazy/manage/lock.lua` の `update()` は、導入済みでないプラグインの記録を消してから書き直す。初回の 1 回目の導入の後にこれが走るため
- **初回起動と確認** (AlmaLinux 導入の手順 17〜19): 開いてから 15 秒ほどで Mason の 12 個が揃った
  - `checkhealth` は ERROR 0 件、WARNING は `fzf` の 1 件
  - `/kensaku` で 3 行目の「検索」に移って `[1/1]`、`:w` で `#動作確認` が `# 動作確認` になった
  - 起動時に `ibus engine` が `xkb:us::eng`、`<C-j>` で `anthy` と lualine の `あ`、`<Esc>` で `xkb:us::eng` と `A` になった。Space 2 回でピッカーが開いた
  - treesitter のパーサーは `Error during download: curl: (22) The requested URL returned error: 403` で入らなかった (検証環境のプロキシが github.com の archive を拒む。git clone とリリースのダウンロードは通る)
- **取り込み・tmux・更新・ロールバック**: 変更の無い状態で取り込みの手順 1 を貼り、`Already up to date.` の後に `git status --short` が空だった
  - tmux の節の手順 1 は 2 回貼っても 1 行だけ書かれた。手順 2 はコンテナの tmux の中で貼り、`terminal-overrides` が 2 行出た
  - 更新の手順 1 は、最新なので 3 つとも `already installed` などの警告だけで終わった。手順 3 は `lazy-lock.json` の 6 行だけを変えた
  - ロールバックの手順 1 は、手順 3 の後の `M lazy-lock.json` を示した。git で戻してから貼り直すと何も出なかった
  - ロールバックの手順 2 は、検証用に置いた `~/.config/nvim.bak` を戻し、`~/.local/share/nvim` などを消した。手順 3 で入力ソースと `on_off` が既定に戻り、手順 4 で `brew list` が空になった
- **Windows の構文**: PowerShell 7.5.4 (Linux 版) の `[System.Management.Automation.Language.Parser]::ParseInput` で、Windows の 17 個のブロックに構文エラーが無いことを確かめた
  - PowerShell 5.1 で使えない `&&` / `||` を使っていないことも確かめた

#### 未確認事項

- GNOME の実機での通し (Super+Space、上部バーの表示、ログインし直しての ibus の読み直し、アイコンの見た目)
- `<C-j>` を押したときに、カーソルのすぐ下に `あ` / `A` が出ること (AlmaLinux 導入の手順 19。PR #26 の機能で、検証した設定には無かった)
- treesitter のパーサーの導入と、ハイライト
- JIS 配列のキーボードで、入力ソースを `us` にしたときの使い勝手
- aarch64 (Raspberry Pi 5 など) での通し。markdown-preview.nvim のプリビルド版が無い
- Windows 11 の手順の通し (scoop の導入から `checkhealth` まで)
- Neovim 0.11 系で、`lazy-lock.json` の nvim-treesitter が動かないこと
- 取り込みの手順 1 と更新の手順 3 を、実際に変更がある状態で通すこと (検証では変更が無い状態で通した)

### 付録: Windows 11 の実機での検証記録 (2026-09-29)

- **環境**: Windows 11 Pro 10.0.26200 (x64)。scoop・Git for Windows 2.55・Microsoft Store 版の PowerShell 7.6.6 が入っている、常用のマシン
  - 手順書の 7 つの scoop のアプリは、どれもバケットの最新だった (neovim 0.12.5、ripgrep 15.2.0、fd 10.5.0、gcc 15.2.0、nodejs 26.10.0、zenhan 0.0.1、lazygit 0.65.1)
  - 各ブロックを Windows PowerShell 5.1.26100 に `-File` で渡した。環境変数はレジストリから組み立て、PATH には Machine の値と、手順書で scoop が入れるものだけを載せた (shim は手順書の 7 つと scoop・7zip)
  - `LOCALAPPDATA` と `TEMP` を一時的な場所に差し替えたので、`%LOCALAPPDATA%\nvim` などは常用の設定とは別の場所になる。退避を見るため、そこに仮の `nvim` と `nvim-data` を置いてから始めた
  - 画面の要る手順 (手順 9・11) は、headless の nvim の `:terminal` (ConPTY) で nvim を起動し、キーを送って画面と状態を読んだ
  - zenhan は、状態をファイルに持って呼び出しを記録するモック (出力と終了コードは本物と同じ) に差し替えた。本物は前面のウィンドウ (検証中はロック画面) の IME を切り替えるため
- **構文**: Windows の 17 個のブロックは、Windows PowerShell 5.1 と PowerShell 7.6.6 のパーサーでエラーが無く、`&&` / `||` も無かった
- **Windows 導入の手順 1〜7**: 手順 1 で `scoop.ps1` の行が出たので、手順 2 は飛ばした。手順 3 は `The 'extras' bucket already exists.` の WARN だけだった
  - 手順 4 は `moved: …\nvim` と `moved: …\nvim-data`、手順 5 は `custom` を出した
  - 手順 6 は何も出さなかった (7 つとも導入済み。scoop は複数を並べると WARN を出さない)。手順 7 は `NVIM v0.12.5` と 7 つの場所を出した
- **プラグイン** (Windows 導入の手順 8): 1 行目は 19 秒。`lazy-lock.json` の 6 個 (AlmaLinux 10 と同じ SchemaStore.nvim など) が書き換わり、restore の後は 38 個とも記録の版で、`git status --short` は何も出さなかった
  - 1 行目で markdown-preview.nvim の build が `install.cmd : 用語 'install.cmd' は…認識されません` で失敗し、`[markdown-preview]: install fail` と出た。lazy.nvim の表示は成功で、`<leader>cp` は `node:internal/modules/cjs/loader` のエラーで開かなかった
  - 原因は、`shell` の PowerShell がカレントディレクトリの `install.cmd` を実行しないこと。Windows では `cmd.exe` で `install.cmd` を実行する build に改めた。改めた後は、初回の導入で 17 秒ほどかけてバイナリが入り、`<leader>cp` でプレビューのサーバーが起動した
- **初回起動と確認** (Windows 導入の手順 9〜11): 開いてから 45 秒で Mason の 12 個、60 秒で treesitter のパーサー 31 個が揃い、ハイライトが効いた
  - Mason の展開に `gzip` / `unzip` / `7z` は要らなかった (zip は `Expand-Archive`、`.tar.gz` は同梱の `tar`)。`7z` を PATH から外して tree-sitter-cli と shellcheck を入れ直しても入った
  - 手順 9 の `Set-Content -Encoding UTF8` (5.1) は、BOM 付き・CRLF のファイルを作る。`fenc=utf-8`・`bomb`・`ff=dos` と判定され、`:w` の後も BOM と CRLF は残った
  - `checkhealth` は ERROR 0 件、WARNING は `fzf` の 1 件だった
  - 手順 11 の確認は 38 項目とも通った: `/kensaku` で 3 行目の「検索」と `[1/1]`、`<Tab>` で「検索」、`:w` で `# 動作確認`、`<C-j>` で `あ` とカーソルのすぐ下の表示 (約 1 秒で消える)、`<Esc>` で `A`、検索の sticky、ピッカーのアイコン
  - モックの呼び出しは `get,1,0,1,0,…` で、操作と 1 対 1 に対応し、余計な呼び出しは無かった
- **IME の不具合** (確認項目の外で見つけた): 挿入モードで日本語のまま、`<C-End>`・`<C-Home>`・`<C-o>zz` などで画面が 2 行以上動くと、挿入モードのまま英数に落ちた
  - snacks.nvim のスムーズスクロールが、アニメーションの 1 コマごとに `:normal!` を実行し、`ModeChanged` の `i:n` / `n:i` が数十回起きていた (`<C-End>` で 91 回)
  - `lua/config/autocmds.lua` で、`state()` に `m` が立つ `i:n` は抜けたと見なさないように直した。直した後は、境界の確認 31 項目 (`<C-c>`・`<C-o>`・`<C-r>=`・置換・端末・ピッカー・終了時の復帰など) のうち、ピッカーの入力欄の `<C-j>` (snacks の既定で候補の移動) を除いて通った
- **シェル**: Store 版の pwsh はアプリ実行エイリアスで、`executable("pwsh")` が 0 になり、`shell` は `powershell` (5.1) になった。pwsh の中から起動すると `pwsh` になった
  - どちらのシェルでも、`system()`・`:!`・`:read !`・`:grep`・`:make` の日本語と終了コードは正しかった
- **Neovide** (0.16.2): スタートメニューからと同じ環境変数で、置き場所を差し替えて起動し、ウィンドウを `PrintWindow` で取り込んで見た (PC はロック中だったが、描画は続いていた)
  - Neovide は Lua の `neovide` テーブルに `preedit_handler` と `commit_handler` を用意し、どちらも `lua/config/ime_preedit.lua` に差し替わった
  - Neovide のソースでは、nvim が 0.12 以上 (開発版なら 0.12.0-dev-1724 以上) のときだけ、未確定文字列を `preedit_handler(raw, 開始, 終了)`、確定を `commit_handler(raw, エスケープ済み)` で渡す
  - 同じ引数で呼ぶと、未確定文字列はカーソル位置に下線付きで入り、行の続きは右へ押し出され、挿入モードのカーソルは未確定文字列の直後に来た。変換中の文節は反転した
  - 確定の後は確定文字列だけが残り、二重表示も extmark の残りも無かった。検索のコマンドラインでは、noice の欄に同じように描かれた
  - `<C-j>` でカーソルのすぐ下に `あ` が出て約 1 秒で消え、lualine と挿入モードのカーソルの色も変わった。全角スペースには波線が出て、アイコンも豆腐にならなかった
  - `shell` は `powershell` (5.1) だった。snacks のスムーズスクロールは Neovide でも有効で、直した後の設定では挿入中の `<C-End>` でも `あ` のままだった
- **取り込み・更新・ロールバック**: 取り込みの手順 2 は、別の clone で lock を更新して push した状態で `Fast-forward` し、6 個を記録の版に揃えた
  - push していないコミットがあると、`fatal: Not possible to fast-forward, aborting.` で止まり、restore は走らなかった
  - `lazy-lock.json` が書き換わっていると、git の既定の設定では `Your local changes … lazy-lock.json` で止まった (`pull.autostash` を true にしていると止まらない)
  - 更新の手順 2 は、7 つとも `(latest version)` と出て `Latest versions for all apps are installed!` で終わった。手順 4 は `lazy-lock.json` だけを変えた
  - ロールバックの手順 5 は、変更と push していないコミットをそれぞれ示した。手順 6 は 401 MB の `nvim-data` を消して、`restored: …` を 2 行出した

#### 未確認事項 (Windows 11)

- 本物の IME (zenhan) での切り替えと、OS 側で切り替えたときの lualine の表示
- Neovide に本物の IME で打ったときの未確定文字列 (画面の描画は、ハンドラを呼ぶ形で確かめた)
- scoop の導入 (Windows 導入の手順 2) と、ロールバックの手順 7
- scoop も Git for Windows も無い、素の Windows 11 からの通し
