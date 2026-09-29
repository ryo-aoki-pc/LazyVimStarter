# Neovim 設定 (LazyVim) の導入手順 (AlmaLinux 10 + GNOME / Windows 11)

## 実施手順

> [!IMPORTANT]
> - **AlmaLinux 10 では、GNOME にログインしたデスクトップの端末で、自分のユーザーのまま実行する** ([SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)だけは、手元の WezTerm から ssh したシェルで貼る)。`sudo -i` した root のシェルでは行わない (Homebrew は root で動かず、`gsettings` は実行したユーザーの設定しか変えない)
> - **AlmaLinux 10 で実行するユーザーは `sudo` できる必要がある** ([AlmaLinux 導入の手順 2・3・8](#almalinux-10-に導入する-1-度だけ))
> - **Windows 11 では、管理者ではない PowerShell で実行する**
> - **対話入力がある**: AlmaLinux 導入の手順 3 (`[y/N]` と EPEL の鍵)、手順 8 (Homebrew の `RETURN` と `sudo` のパスワード)、手順 10 (`brew` の `[y/n]`)、[GitLab プレビューのトークンの節](#gitlab-プレビューのトークンを設定する-任意)の手順 1〜4 (トークンと GitLab の URL)。答えてから次の手順を貼る
> - **Neovim の画面が開く**: AlmaLinux 導入の手順 17・19、Windows 導入の手順 9・11、[SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 2。`:qa` で閉じてから次の手順を貼る
> - **AlmaLinux 導入の手順 15 の後で、ログアウトしてログインし直す** (入れた ibus-anthy と入力ソースを読み直させる)。[上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)の手順 2 でも、拡張を読ませるためにログインし直す

| シナリオ | 頻度 | 内容 |
|---|---|---|
| [AlmaLinux 10 に導入する](#almalinux-10-に導入する-1-度だけ) | マシンごとに 1 度 | 外部コマンド・Neovim・日本語入力・フォントを入れ、この設定を clone して初回起動する |
| [Windows 11 に導入する](#windows-11-に導入する-1-度だけ) | マシンごとに 1 度 | scoop で外部コマンド・Neovim・zenhan を入れ、この設定を clone して初回起動する |
| [ほかのマシンの変更を取り込む](#ほかのマシンの変更を取り込む-繰り返し) | 繰り返し | 別のマシンで push した設定と `lazy-lock.json` を取り込み、プラグインの版を揃える |
| [カーソル色を tmux で効かせる (任意)](#カーソル色を-tmux-で効かせる-任意) | 任意、1 度だけ | tmux の中でも、挿入モードのカーソル色を IME の状態で変える (AlmaLinux 10) |
| [GNOME の上部バーを IME 連携に合わせる (任意)](#gnome-の上部バーを-ime-連携に合わせる-任意) | 任意、1 度だけ | Neovim が IME を切り替えても、GNOME の上部バーと Super+Space の順番がずれないようにする (AlmaLinux 10 + GNOME 49) |
| [GitLab プレビューのトークンを設定する (任意)](#gitlab-プレビューのトークンを設定する-任意) | 任意、1 度だけ | `<leader>cp` のプレビューを GitLab 本体に描かせるため、アクセストークン (と GitLab の URL) を環境変数にする |
| [SSH 越しのヤンクを手元のクリップボードに送る (任意)](#ssh-越しのヤンクを手元のクリップボードに送る-任意) | 任意、1 度だけ | 手元の WezTerm から ssh した AlmaLinux 10 の Neovim で、ヤンクが OSC 52 で手元のクリップボードに入ることを確かめる (向きは Neovim → 手元だけ) |
| [更新](#更新) | 更新のたび | Neovim・外部コマンド・プラグインを上げる |
| [ロールバック](#ロールバック) | 戻すとき | この設定とプラグインを消し、退避した設定と入力ソースを戻す |

- 初めてのマシンでは、自分の OS の「導入する」を上から順に貼る。以後は、必要なシナリオと節だけを貼る
- 手順の番号はシナリオ (見出し) ごとに 1 から数える。ほかのシナリオの手順は「AlmaLinux 導入の手順 3」「Windows 導入の手順 2」「取り込みの手順 1」のように呼ぶ
- 変数は無い。設定の置き場所 (`~/.config/nvim` / `%LOCALAPPDATA%\nvim`) と clone 元の URL は、コマンドに直接書いてある
  - 例外は [GitLab プレビューのトークンを設定する (任意)](#gitlab-プレビューのトークンを設定する-任意) だけ。トークンと GitLab の URL は文書に書かず、貼った後に入力する
- AlmaLinux 10 のブロックは bash、Windows 11 のブロックは PowerShell で貼る
- 各手順の末尾の「補足」(折り畳み) と後半の[補足](#補足)は、実行するだけなら読まなくてよい。折り畳みの中のブロックも貼らなくてよい
- この設定で何ができるかは [README](../README.md)。外部コマンドの用途は[必要なもの一覧](#必要なもの一覧)

> [!WARNING]
> **AlmaLinux 10 の手順は x86_64 のコンテナで通した。GNOME の実機では、導入済みの PC で AlmaLinux 導入の手順 16〜19 と取り込みの手順 1 だけを通した** (手順 1〜15 は、システムを変えずに到達点を確かめただけ)。aarch64 では通していない。**上部バーの節は、画面の無い gnome-shell でだけ確かめた** (本物のログインでは通していない)。**Windows 11 の手順は実機で通したが、IME の切り替えは確かめていない** (zenhan をモックに差し替えた)。**GitLab プレビューは、本物の GitLab では表示できることだけを確かめた** (記法ごとの見え方は模擬の API で確かめた)。**SSH 越しのクリップボードは、Windows の WezTerm と GNOME の画面では確かめていない** (AlmaLinux 10 の実機で、WezTerm の nightly を画面の無い mutter の上で動かし、ssh して確かめた)。範囲は[対象と検証環境](#対象と検証環境)。

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
   sudo dnf install git ripgrep fd-find gcc curl tar gzip unzip nodejs nodejs-npm file procps-ng ibus-anthy wl-clipboard
   ```

   - 何に使うかは[必要なもの一覧](#必要なもの一覧)
   - EPEL の署名鍵をまだ取り込んでいなければ、ここで 1 回だけ確認を求められる
   - 鍵の fingerprint が `7D8D 15CB FC4E 6268 8591 FB26 33D9 8517 E37E D158` (`Fedora (epel10)`) であることを確かめてから `y` と答える
   - **次の手順は、トランザクション表の `[y/N]` と鍵の確認に答えてから貼る** (続けて貼ると答えとして食われる)

   <details>
   <summary>補足: dnf で入れるもの</summary>

   - **`unzip` は必須**: Mason は zip で配布されるツール (`stylua` など) の展開に使う。無いと**そのツールだけ**が静かに入らず、ほかは入るので気付きにくい
   - **`gcc`**: nvim-treesitter は各言語のパーサーを手元で C としてコンパイルする。C コンパイラが無いとハイライトが効かない
   - **`nodejs` / `nodejs-npm`**: Mason が `markdownlint-cli2` / `bash-language-server` / `json-lsp` / `yaml-language-server` を npm パッケージとして入れる。**node を消すと Markdown の lint と整形が丸ごと止まる**
   - `npm` と書いても `nodejs-npm` に解決されて入るが、この節の手順 4 の `rpm -q` はパッケージ名でしか引けないので、両方の手順で `nodejs-npm` と書いている
   - **`file` / `procps-ng`**: Homebrew の前提 (この節の手順 8)。GNOME の PC には入っていることが多い
   - **`ibus-anthy`**: AlmaLinux 10 の Workstation には最初から入っている。入っていれば dnf は `already installed` と出して飛ばす。依存として `ibus-anthy-python` と `anthy-unicode` が入る
   - `curl` / `tar` / `gzip` は treesitter と Mason の取得・展開に使う。最小構成のコンテナにも入っていた
   - **Deno は要らない**: 日本語のローマ字検索 (Migemo) は純 Lua の luamigemo が辞書ごと同梱している
   - **`wl-clipboard`**: `<leader>ci` (img-clip.nvim) がクリップボードの画像を `wl-paste` で取り出す。EPEL にある。無くても `<leader>ci` が使えないだけ
   - コンテナ (最小構成の `almalinux:10`) での実測は、101 個を入れて 4 個を更新した (git の依存の perl など。`wl-clipboard` を足す前の数)。GNOME の PC ではもっと少ない

   </details>

1. dnf で入ったか確かめる。

   ```bash
   rpm -q git ripgrep fd-find gcc curl tar gzip unzip nodejs nodejs-npm file procps-ng ibus-anthy wl-clipboard
   node --version
   command -v fd rg gdbus busctl wl-paste
   ```

   - どの行も `package … is not installed` にならなければよい
   - `node --version` が `v22.…` と出る
   - `fd` / `rg` / `gdbus` / `busctl` / `wl-paste` の 5 つの場所が出る (`gdbus` と `busctl` は IME 連携が ibus と話すのに使う)

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
   /usr/bin/gsettings get org.gnome.desktop.input-sources sources
   /usr/bin/gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'anthy')]"
   /usr/bin/gsettings get org.gnome.desktop.input-sources sources
   ```

   - 最後の行が `[('xkb', 'us'), ('ibus', 'anthy')]` になればよい
   - 最初の行は変える前の値。ほかの入力ソースは消える
   - 日本語と英数の切り替えは Super+Space になる
   - **注意**: JIS 配列のキーボードでも `us` にする。IME 連携が英数を `xkb:us::eng` に固定しているため (この手順の補足)
   - `gsettings` は `/usr/bin/gsettings` と場所まで書く。Homebrew の `gsettings` は GNOME の設定 (dconf) に書かない (この手順の補足)

   <details>
   <summary>補足: 入力ソースを 2 つとも登録する理由</summary>

   - IME 連携 (`lua/config/ime.lua`) は、ibus の global engine を `anthy` (日本語) と `xkb:us::eng` (英数) の間で切り替える。どちらも GNOME の入力ソースに登録しておかないと、gnome-shell が管理外のエンジンを巻き戻す
   - 英数のエンジン名は `ime.lua` の中で `xkb:us::eng` に固定してある。入力ソースを `('xkb', 'jp')` にすると、Neovim が英数に戻すたびに US 配列のエンジンになる (コードから読んだもので、JIS 配列では試していない)
   - 先頭の `export` は tmux の中で貼るときのため。tmux の中では `DBUS_SESSION_BUS_ADDRESS` が無いことがあり、そのとき `gsettings` は既定値しか読めず、書き込みも黙って効かない
   - GNOME の端末ではもともと同じ値が入っているので、`export` しても変わらない
   - **`/usr/bin/gsettings` と書く理由**: Homebrew の glib (cairo・ffmpeg・imagemagick・gnupg などの依存で入る) にも `gsettings` があり、`brew shellenv` の後は PATH の先頭に来る。これは dconf を使えず、`~/.config/glib-2.0/settings/keyfile` に黙って書くので、GNOME も Anthy も読まない (AlmaLinux 10 の実機で、この節の手順 13〜15 が効いていなかった)
   - Neovim から ibus への通信には `busctl` (systemd) か `gdbus` (glib2) を使う。`gdbus` があれば OS 側の切り替えも検知できるので、lualine の `あ` / `A` がずれない
   - 実装と運用上の注意 (変換中の `<Esc>` は 2 回、Neovim を 2 つ起動したときの制限など) は [README の日本語入力・検索](../README.md#日本語入力検索)

   </details>

1. Anthy の `on_off` のキーから `Ctrl+J` と `Ctrl+space` を外した値を作る。

   ```bash
   ANTHY_SHORTCUT=$(/usr/bin/gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | sed "s/'on_off': <\['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J'\]>/'on_off': <['Zenkaku_Hankaku']>/")
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
   /usr/bin/gsettings set org.freedesktop.ibus.engine.anthy.shortcut default "${ANTHY_SHORTCUT:?AlmaLinux 導入の手順 14 の ANTHY_SHORTCUT が空のまま。AlmaLinux 導入の手順 14 を貼り直す}"
   /usr/bin/gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | grep -o "'on_off': <\[[^]]*\]>"
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
   - `Error running markdownlint-cli2: ENOENT` が 1 回出てもよい (Mason が入れ終わる前に lint が走っただけ)
   - `:Mason` を開き、Installed が 11 個になり、導入中のものが無くなるまで待つ (`q` で閉じる。tree-sitter の CLI を別に入れてあれば 10 個)
   - 待ったら `:qa` で閉じる
   - **次の手順は、`:qa` で閉じてから貼る** (続けて貼ると Neovim への入力として食われる)

   <details>
   <summary>補足: 初回起動で入るもの</summary>

   - ファイルを開くのは、LSP のサーバーがファイルを開いたとき (`LazyFile`) に初めて入るため
   - Mason が入れるのは 11 個: `bash-language-server` / `json-lsp` / `lua-language-server` / `markdownlint-cli2` / `marksman` / `shellcheck` / `shfmt` / `stylua` / `taplo` / `tree-sitter-cli` / `yaml-language-server`
   - tree-sitter の CLI が PATH にあると (Homebrew の `tree-sitter-cli` など)、LazyVim は Mason で `tree-sitter-cli` を入れないので 10 個になる
   - そのうち 4 個 (`bash-language-server` / `json-lsp` / `markdownlint-cli2` / `yaml-language-server`) は npm で入る
   - コンテナでは、開いてから 15 秒ほどで揃い、`:Mason` に `Installed (12)` と出た (markdown-toc を外す前の記録。今は 11 個)
   - 途中で閉じても、次に起動したときに足りないものが入る (コンテナで確認)
   - treesitter のパーサーは GitHub の archive から取得し、`gcc` でビルドする
   - コンテナではパーサーの取得がプロキシに拒まれた ([付録](#付録-コンテナでの検証記録-2026-09-28))。AlmaLinux 10 の実機では、開いてから 13 秒で 30 個が入り、ハイライトが効いた ([付録](#付録-almalinux-10-の実機での導入と取り込みの検証記録-2026-09-29))
   - `ENOENT` の通知は、markdownlint-cli2 が入る前に開いたファイルを lint しようとしたもの。入った後の起動では出ない

   </details>

1. 外部コマンドと Mason のツールが揃ったかを、`checkhealth` で確かめる。

   ```bash
   ls ~/.local/share/nvim/mason/bin
   nvim --headless "+Lazy! load mason.nvim luamigemo" "+checkhealth lazyvim luamigemo" "+w! /tmp/lazyvim-health.txt" +qa
   grep -E 'ERROR|WARNING' /tmp/lazyvim-health.txt
   ```

   - `mason/bin` に `markdownlint-cli2` / `marksman` / `stylua` / `tree-sitter` などが並ぶ
   - `grep` が何も出さないか、`` WARNING `fzf` is not installed `` の 1 行だけならよい (無視してよい。fzf が入っていれば出ない)
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
   - `<C-j>` を押したときは、カーソルのすぐ下にも `あ` / `A` が約 1 秒出る
   - `/` を押す。最下段の検索欄の右端に `A` が出る。`<C-j>` で `あ` に変わり、検索欄のカーソルのすぐ上にも `あ` が約 1 秒出て、カーソルが橙になる
   - `<Esc>` で抜ける。下の表示が `A` に戻り、次の `/` は `あ` で始まる (検索の sticky)。`<C-j>` で `A` にしてから `<Esc>` で抜ける
   - Space を 2 回押してファイルピッカーを開き、アイコンが豆腐でないことを見る (`<Esc>` で閉じる)
   - `:qa!` で閉じる (`o` で足した行は保存しない)
   - これで導入は終わり

   <details>
   <summary>補足: 機能の確かめ方</summary>

   - 日本語検索は Migemo (luamigemo) で、ローマ字のまま日本語にマッチする。辞書は同梱なのでネットワークは要らない
   - 英単語や空白・記号を含む入力はそのまま検索する (ローマ字として読めるときだけ変換する)
   - `s` → `nihon` → `;` → ラベルで「日本語」の「日本」へ飛べることも見られる (flash.nvim。`;` を打つまではラベルで飛ばない)
   - `<Tab>` の候補は、バッファ内で Migemo に一致した文字列を ripgrep で集めたもの。ローマ字が 3 文字以上のときだけ出る
   - 整形は保存時に conform.nvim が `markdownlint-cli2 --fix` を掛ける。`#動作確認` は MD018 (見出しの `#` の後の空白) の違反
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
   - `gzip` と `unzip` は要らない。Mason は Windows では zip を PowerShell の `Expand-Archive` で、`.tar.gz` を同梱の `tar` で展開する。この設定で入る 11 個は、どちらかか、展開の要らない exe・npm で済む
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

   - `:Mason` を開き、Installed が 11 個になり、導入中のものが無くなるまで待つ (`q` で閉じる)
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
- 外したプラグインとツールは、自動では消えない。消すなら Neovim で `:Lazy clean` (無効にしたプラグインのディレクトリ) と `:MasonUninstall <名前>` (例: markdown-preview.nvim と markdown-toc を外した変更の後なら `:MasonUninstall markdown-toc`)

1. AlmaLinux 10 では、設定を最新にしてプラグインを揃える。

   ```bash
   git -C ~/.config/nvim pull --ff-only && nvim --headless "+Lazy! restore" +qa
   git -C ~/.config/nvim status --short
   ```

   - `git status --short` が何も出さなければ、`lazy-lock.json` の版に揃っている
   - `git status --short` が `M lazy-lock.json` を出したら、取り込んだ変更で増えたプラグインを起動時に入れたとき、lock が入っていた古い版で書き直されている (`restore` はその lock に揃えた)。`git -C ~/.config/nvim checkout -- lazy-lock.json` で戻し、`nvim --headless "+Lazy! restore" +qa` をもう一度貼る (2 回目は入れるものが無いので書き直されない)
   - `pull` が `Not possible to fast-forward` で止まったら、このマシンに push していないコミットがある。先に push するか、`git -C ~/.config/nvim log --oneline '@{u}..'` で中身を見る
   - `pull` が `Your local changes to the following files would be overwritten by merge:` で `lazy-lock.json` を挙げて止まったら、このマシンで lock が書き換わっている。`:Lazy update` の結果として残すのでなければ、`git -C ~/.config/nvim checkout -- lazy-lock.json` で戻してから、この手順を貼り直す

1. Windows 11 では、(この節の手順 1 の代わりに) 設定を最新にしてプラグインを揃える。

   ```powershell
   git -C "$env:LOCALAPPDATA\nvim" pull --ff-only; if ($?) { nvim --headless "+Lazy! restore" +qa }
   git -C "$env:LOCALAPPDATA\nvim" status --short
   ```

   - `git status --short` が何も出さなければ、`lazy-lock.json` の版に揃っている
   - `git status --short` が `M lazy-lock.json` を出したら、取り込んだ変更で増えたプラグインを起動時に入れたとき、lock が入っていた古い版で書き直されている (`restore` はその lock に揃えた)。`git -C "$env:LOCALAPPDATA\nvim" checkout -- lazy-lock.json` で戻し、`nvim --headless "+Lazy! restore" +qa` をもう一度貼る (2 回目は入れるものが無いので書き直されない)
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

## GNOME の上部バーを IME 連携に合わせる (任意)

- Neovim がモードに合わせて IME を切り替えても、GNOME の上部バーの表示と Super+Space の順番がずれないようにする
- GNOME Shell は ibus の engine が外から変わっても、上部バーと Super+Space が基準にする「今の入力ソース」を更新しない。そのため、この節を行わないと Neovim を開いた時点で上部バーがずれ、最初の Super+Space が空振りする
- この設定のリポジトリにある GNOME Shell の拡張 (`gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com`) を有効にする。engine が変わったときに「今の入力ソース」を合わせるだけで、engine やキー配列は変えない
- AlmaLinux 10 + GNOME 49 のときだけ行う。拡張は GNOME Shell の内部の関数を使うので、GNOME を上げたらこの節の手順 4 で確かめる
- **この節の手順 2 で、ログアウトしてログインし直す**

1. 拡張を、GNOME Shell が拡張を探す場所につなぐ。

   ```bash
   mkdir -p ~/.local/share/gnome-shell/extensions
   ln -sfn ~/.config/nvim/gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com ~/.local/share/gnome-shell/extensions/
   ls -l ~/.local/share/gnome-shell/extensions/
   ```

   - `ibus-engine-follow@ryo-aoki-pc.github.com -> …/.config/nvim/gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com` と出ればよい
   - つないでおくので、[取り込み](#ほかのマシンの変更を取り込む-繰り返し)で拡張が変わると、次のログインから新しい方が使われる

1. ログアウトしてログインし直す。

   - GNOME Shell (Wayland) は、新しい拡張をログインのときにしか探さない
   - **次の手順は、ログインし直した後の端末で貼る**

1. 拡張を有効にする。

   ```bash
   gnome-extensions enable ibus-engine-follow@ryo-aoki-pc.github.com
   gnome-extensions info ibus-engine-follow@ryo-aoki-pc.github.com | grep -E 'Enabled|State'
   ```

   - `Enabled: Yes` と `State: ACTIVE` が出ればよい
   - `doesn't exist` と出たら、この節の手順 1 のつなぎ先が無い (設定を取り込んでいない) か、ログインし直していない
   - `State: OUT OF DATE` と出たら、GNOME Shell の版が拡張の `metadata.json` の `shell-version` に無い

1. Neovim を開き、上部バーが Neovim の IME の状態に付いてくることを確かめる。

   ```bash
   printf '%s\n' '#動作確認' '' '日本語の検索を試す。' > /tmp/lazyvim-check.md
   nvim /tmp/lazyvim-check.md
   ```

   - 開いた時点で、上部バーの入力ソースが英語 (US) になる (Neovim がノーマルモードで英数にするため)
   - `o` → `<C-j>` で、上部バーが Anthy (`あ`) になる。`<Esc>` で英語 (US) に戻る
   - ノーマルモードで Super+Space を 1 回押すと、上部バーと lualine の `あ` / `A` が一緒に変わる (空振りしない)
   - `:qa!` で閉じる

   <details>
   <summary>補足: 拡張がしていること</summary>

   - GNOME Shell 49.4 の `ui/status/keyboard.js` は、自分で入力ソースを切り替えたとき (`activateInputSource()`) だけ「今の入力ソース」を書き換える。`misc/ibusManager.js` は、ibus の `GlobalEngineChanged` を受けても engine の名前を控えるだけ
   - 拡張は同じシグナルを受け、今の入力ソースが engine と違えば、`InputSourceManager` の `_currentInputSourceChanged()` (内部の関数) で今の入力ソース・上部バーの表示・Super+Space の順番 (MRU) を更新する
   - `activateInputSource()` を呼ばないのは、キーボードを一時的に掴むため。掴むと端末にフォーカスの出入りが届き、engine も設定し直してしまう
   - GNOME Shell 自身の切り替え (Super+Space) では、シグナルが届く前に今の入力ソースが更新済みなので何もしない。ibus は同じ engine を設定し直してもシグナルを出さないので、行き来は起きない
   - パスワード欄にいる間 (GNOME Shell が ibus を止めて英数に切り替えている間) は何もしない
   - 内部の関数が無くなったら何もしない (上部バーがずれるだけの、この節を行う前の状態に戻る)

   </details>

1. 元に戻すときは、拡張を無効にして、つなぎを外す。

   ```bash
   gnome-extensions disable ibus-engine-follow@ryo-aoki-pc.github.com
   rm ~/.local/share/gnome-shell/extensions/ibus-engine-follow@ryo-aoki-pc.github.com
   ```

   - 上部バーは、Neovim が切り替えた後もそれまでの入力ソースのまま残るようになる (この節を行う前と同じ)

---

## GitLab プレビューのトークンを設定する (任意)

- `<leader>cp` のプレビューを、GitLab 本体の描画 (GitLab の Markdown API) で見るための設定。しなくても、プレビューは近似表示で動く
- 先に GitLab で、スコープが `read_api` の個人アクセストークンを作っておく (GitLab の「ユーザー設定」→「アクセストークン」)
- 編集中の内容とトークンは、ここで設定する GitLab (空なら gitlab.com) にだけ送られる ([README](../README.md#markdown--glfm-執筆))
- AlmaLinux 10 はこの節の手順 1・2・5、Windows 11 はこの節の手順 3・4・6 を貼る。消すときは手順 7 (AlmaLinux 10) / 手順 8 (Windows 11)

1. AlmaLinux 10 では、トークンを入力して `~/.bashrc` に書く。

   ```bash
   read -rsp 'GitLab のトークン: ' t && echo && sed -i '/^export GITLAB_TOKEN=/d' ~/.bashrc && printf 'export GITLAB_TOKEN=%q\n' "$t" >> ~/.bashrc; unset t
   ```

   - `GitLab のトークン: ` と出るので、トークンを貼って Enter を押す (画面には出ない)
   - 前に書いた `GITLAB_TOKEN` の行があれば、書き直す
   - **次の手順は、トークンを入力してから貼る**

   <details>
   <summary>補足: トークンの置き場所</summary>

   - `~/.bashrc` は平文。ホームディレクトリは自分だけが読める (0700) ので、ほかのユーザーからは読めない
   - GNOME から起動する GUI のアプリ (Neovide など) は `~/.bashrc` を読まない。そちらでも使うなら、`~/.config/environment.d/gitlab.conf` に `GITLAB_TOKEN=…` の形で書き、ログインし直す
   - 名前は GitLab の CLI (glab) と同じにしてある

   </details>

1. AlmaLinux 10 で、gitlab.com 以外の GitLab (社内の GitLab など) を使うときは、その URL を入力して `~/.bashrc` に書く。

   ```bash
   read -rp 'GitLab の URL (gitlab.com なら空のまま Enter): ' h && sed -i '/^export GITLAB_HOST=/d' ~/.bashrc && { [ -z "$h" ] || printf 'export GITLAB_HOST=%q\n' "$h" >> ~/.bashrc; }; unset h
   ```

   - `https://gitlab.example.com` のように入力する (ホスト名だけでもよい)
   - 空のまま Enter を押すと、`GITLAB_HOST` を書かない (前に書いた行も消す)。送り先は gitlab.com になる
   - **次の手順は、URL を入力してから貼る**

1. Windows 11 では、(この節の手順 1 の代わりに) トークンを入力して、ユーザーの環境変数にする。

   ```powershell
   [Environment]::SetEnvironmentVariable('GITLAB_TOKEN', [pscredential]::new('gitlab', (Read-Host -AsSecureString 'GitLab のトークン')).GetNetworkCredential().Password, 'User')
   ```

   - `GitLab のトークン: ` と出るので、トークンを貼って Enter を押す (画面には `*` で出る)
   - Enter の後、プロンプトが戻るまで 2 秒ほどかかる
   - 前に設定した値があれば、置き換わる
   - **次の手順は、トークンを入力し、プロンプトが戻ってから貼る**

   <details>
   <summary>補足: トークンの置き場所</summary>

   - ユーザーの環境変数は、レジストリ (`HKCU\Environment`) に平文で入る。ほかのユーザーからは読めない
   - 設定した後に起動したアプリ (端末・スタートメニューから開く Neovide) にだけ渡る。開いたままの端末には渡らない
   - 時間がかかるのは、変えたことを開いている全てのウィンドウに知らせ終わるまで戻らないため (検証した PC では 1 回 2 秒ほど)

   </details>

1. Windows 11 で、(この節の手順 2 の代わりに) gitlab.com 以外の GitLab を使うときは、その URL を入力して、ユーザーの環境変数にする。

   ```powershell
   $h = Read-Host 'GitLab の URL (gitlab.com なら空のまま Enter)'; if ($h) { [Environment]::SetEnvironmentVariable('GITLAB_HOST', $h, 'User') } else { [Environment]::SetEnvironmentVariable('GITLAB_HOST', $null, 'User') }
   ```

   - `https://gitlab.example.com` のように入力する (ホスト名だけでもよい)
   - 空のまま Enter を押すと、`GITLAB_HOST` を消す。送り先は gitlab.com になる
   - Enter の後、プロンプトが戻るまで 2 秒ほどかかる
   - **次の手順は、URL を入力し、プロンプトが戻ってから貼る**

1. AlmaLinux 10 では、新しい端末でこの設定の README を開き、プレビューで確かめる。

   ```bash
   nvim ~/.config/nvim/README.md
   ```

   - `<leader>cp` を押すとブラウザが開き、右上に `GitLab: gitlab.com` (設定した GitLab のホスト名) と出ればよい
   - `近似表示` と出たら、上のバナーに理由が出る ([注意点](#注意点))
   - `<leader>cp` をもう一度押すと止まる。`:qa` で閉じる

1. Windows 11 では、(この節の手順 5 の代わりに) 新しい端末でこの設定の README を開き、プレビューで確かめる。

   ```powershell
   nvim "$env:LOCALAPPDATA\nvim\README.md"
   ```

   - 確かめることは、この節の手順 5 と同じ
   - Neovide で使うなら、Neovide も起動し直す

1. AlmaLinux 10 で、設定を消すときは、`~/.bashrc` から消す。

   ```bash
   sed -i '/^export GITLAB_\(TOKEN\|HOST\)=/d' ~/.bashrc
   ```

   - GitLab の側でも、「アクセストークン」からそのトークンを取り消す
   - 開いたままの端末には値が残る。端末を開き直す

1. Windows 11 で、(この節の手順 7 の代わりに) 設定を消すときは、ユーザーの環境変数から消す。

   ```powershell
   foreach ($n in 'GITLAB_TOKEN', 'GITLAB_HOST') { [Environment]::SetEnvironmentVariable($n, $null, 'User') }
   ```

   - プロンプトが戻るまで 4 秒ほどかかる (2 つ消すので、この節の手順 3 の倍)
   - GitLab の側でも、「アクセストークン」からそのトークンを取り消す

---

## SSH 越しのヤンクを手元のクリップボードに送る (任意)

- 手元の端末から AlmaLinux 10 に ssh して Neovim を使うとき、`y` `d` `x` などでレジスタに入れたものを、手元のクリップボードにも入れる
- 仕組みは端末の OSC 52 で、この設定が SSH のシェル (`SSH_CONNECTION` がある) で起動したときだけ使う。手元にも AlmaLinux 10 にも、足すソフトは無い
- 向きは Neovim → 手元だけ。手元でコピーしたものは、端末の貼り付け (WezTerm は Ctrl+Shift+V) で Neovim に入れる
- 手元の端末は WezTerm の nightly を想定している。安定版 (20240203) は、設定ファイルがあると OSC 52 を捨てる ([注意点](#注意点))
- 先に[取り込みの手順 1](#ほかのマシンの変更を取り込む-繰り返し)で、AlmaLinux 10 の設定を最新にしておく
- **この節は、GNOME の端末ではなく、手元の WezTerm から ssh したシェルで貼る**。tmux の中の Neovim は扱わない

1. SSH のシェルで、この設定が OSC 52 を使うことを確かめる。

   ```bash
   printf 'SSH_CONNECTION=%s\n' "${SSH_CONNECTION:-(無い)}"
   nvim --headless "+lua io.stdout:write((vim.g.clipboard or {}).name or '(無い)', '\n')" +qa
   ```

   - 1 行目が `SSH_CONNECTION=` に続けて、接続元と接続先のアドレスとポートを 4 つ出せばよい
   - 2 行目が `OSC 52 (copy only)` と出ればよい
   - `SSH_CONNECTION=(無い)` と出たら、SSH のシェルではない (`sudo -i` や `su -` のシェルでは消える)。ssh でログインしたユーザーのシェルで貼り直す
   - 2 行目が `(無い)` と出たら、設定が古い。取り込みの手順 1 を貼ってから、この手順を貼り直す

1. 試験用のテキストを開き、ヤンクした行が手元のクリップボードに入ることを確かめる。

   ```bash
   printf '%s\n' 'SSH 越しのヤンクを試す。' > /tmp/lazyvim-ssh.txt
   nvim /tmp/lazyvim-ssh.txt
   ```

   - `yy` を押す。手元のアプリ (メモ帳など) に貼り付けると、`SSH 越しのヤンクを試す。` が入る
   - `p` を押す。待たされずに、同じ行がすぐ下に入る
   - `:set clipboard?` が `clipboard=unnamedplus` と出る
   - `:qa!` で閉じる

   <details>
   <summary>補足: 仕組みと、手元から Neovim への向き</summary>

   - ヤンクや削除のたびに、Neovim が OSC 52 (中身を base64 にしたエスケープシーケンス) を画面に書き、WezTerm がそれを手元のクリップボードに入れる。SSH は画面の出力として運ぶだけ
   - LazyVim は SSH のシェルでは `clipboard` を空にするので、そのままでは `yy` が手元に入らない (WezTerm の nightly なら、`"+yy` は入る)
   - Neovim は `clipboard` が空のときしか OSC 52 を自動で選ばない。この設定は `lua/config/options.lua` で OSC 52 を明示し、`clipboard` をローカルと同じ `unnamedplus` にしている
   - `p` は端末に問い合わせず、この Neovim が最後に送った内容を貼る (行単位・矩形の形も保つ)。OSC 52 の読み出しには WezTerm も Windows Terminal も応えず、Neovim の内蔵の読み出しは 1 回ごとに 10 秒待つため
   - 手元でコピーしたものは、WezTerm の貼り付け (Ctrl+Shift+V) で入れる。Neovim には貼り付け (bracketed paste) として届き、挿入モードでもノーマルモードでもカーソルの後ろに入る。レジスタには入らない
   - ローカル (GNOME の端末や Neovide) で起動したときは、これまでどおり `wl-copy` などを使う (`SSH_CONNECTION` が無いので、この節の設定は効かない)

   </details>

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
- GitLab プレビューのトークンを設定していたら、[その節](#gitlab-プレビューのトークンを設定する-任意)の手順 7 (AlmaLinux 10) / 手順 8 (Windows 11) で消す
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
   /usr/bin/gsettings reset org.gnome.desktop.input-sources sources
   /usr/bin/gsettings reset org.freedesktop.ibus.engine.anthy.shortcut default
   /usr/bin/gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | grep -o "'on_off': <\[[^]]*\]>"
   ```

   - `'on_off': <['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J']>` と出ればよい
   - 入力ソースは既定 (空) に戻る。導入の前の値に戻すなら、[AlmaLinux 導入の手順 13](#almalinux-10-に導入する-1-度だけ) の最初の行に出た値を `/usr/bin/gsettings set` で書く

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
  - 変数は無い。読者が書き換える値も無い (GitLab プレビューのトークンの節だけは、トークンと URL を貼った後に入力する)
  - AlmaLinux 10 は dnf + EPEL と Homebrew、Windows 11 は scoop で入れる
- **状態**:
  - **AlmaLinux 10 の導入は、x86_64 のコンテナでのみ通した (2026-09-28)。実機では、この形では通していない**
    - クラウドホスト上の Docker の `almalinux:10` (AlmaLinux 10.2) に、sudo のできる一般ユーザーを作り、端末 (tmux) に**この文書のコードブロックをそのまま貼って**通した
    - 通したもの: AlmaLinux 導入の手順 1〜19、取り込みの手順 1、tmux の節、更新の手順 1・3、ロールバックの手順 1〜4
    - GNOME の代わりに、セッションバス (`dbus-daemon --session`) と dconf で `gsettings` を動かした。IME 連携は ibus-daemon を `--panel disable` で起動して確かめた
    - 確かめたこと:
      - 入るパッケージと版、EPEL の鍵、`brew` の確認、`fc-match`
      - Anthy のキーの置き換え (ほかのキーが残ること)
      - `lazy-lock.json` の版に揃うこと、Mason の 12 個 (当時。markdown-toc を外した今は 11 個)、`checkhealth` の ERROR が 0 件
      - `/kensaku` の検索、保存時の整形、`<C-j>` での `anthy` ↔ `xkb:us::eng` と lualine の `あ` / `A`
    - **確かめていないこと**:
      - treesitter のパーサーの導入 (検証環境のプロキシが github.com の archive を 403 で拒んだ)
      - GNOME の画面・Super+Space・アイコンの見た目・ログインし直しての ibus の読み直し
      - aarch64
      - PR #26 で入った、カーソルのすぐ下の `あ` / `A` の表示 (検証した設定は、その前の 9c4e8d9)
      - **markdown-preview.nvim と markdown-toc を外し、GitLab プレビュー・img-clip.nvim・GLFM のスニペットを足した変更の後は、通していない** (AlmaLinux 導入の手順 3・4 に足した `wl-clipboard`、画像の貼り付け、GitLab プレビューのトークンの節を含む)
      - 検索中の `あ` / `A` の表示 (検索欄の右端・カーソルのすぐ上) と、コマンドラインのカーソル色 (この検証の後に足した機能)
    - 検証の都合で変えたこと (手順には含めない): sudo をパスワード無しにし、プロキシの環境変数と CA を渡した ([付録](#付録-コンテナでの検証記録-2026-09-28))
  - **Windows 11 は、実機 (Windows 11 Pro 10.0.26200、x64) で通した (2026-09-29)。設定とデータの置き場所は、一時的な場所に差し替えた**
    - `LOCALAPPDATA` と `TEMP` を差し替え、PATH をレジストリの値から組み立て直した Windows PowerShell 5.1 に、**この文書のコードブロックをそのまま渡して**通した ([付録](#付録-windows-11-の実機での検証記録-2026-09-29))
    - 通したもの: Windows 導入の手順 1・3〜11 (scoop が入っていたので手順 2 は飛ばした)、取り込みの手順 2、更新の手順 2・4、ロールバックの手順 5・6
    - 確かめたこと:
      - `lazy-lock.json` の版に揃うこと、Mason の 12 個 (当時。今は 11 個)、treesitter のパーサー 31 個とハイライト、`checkhealth` の ERROR が 0 件
      - `/kensaku` の検索、`<Tab>` の候補、保存時の整形、`<C-j>` と lualine の `あ` / `A`、カーソルのすぐ下の表示、検索の sticky
      - 取り込みの手順 2 を、変更がある状態・push していないコミットがある状態・`lazy-lock.json` が書き換わった状態で通すこと
      - Neovide 0.16.2 の画面での、未確定文字列 (下線・変換中の文節の反転・カーソルの位置)・カーソルのすぐ下の表示・lualine の `あ` / `A` (未確定文字列は、Neovide が IME から受け取ったときと同じ引数でハンドラを呼んで描かせた)
      - 検索中の `あ` / `A` の表示 (検索欄の右端・カーソルのすぐ上) と、コマンドラインのカーソル色。手順を通した後に足した機能なので、Neovide 0.16.2 と端末 (ConPTY) で個別に確かめた (zenhan はモック)
    - **確かめていないこと**:
      - 本物の IME の切り替え (zenhan は、呼び出しを記録するモックに差し替えた。本物は前面のウィンドウの IME を切り替えるため)
      - Neovide に本物の IME で打ったとき、Neovide がハンドラを呼ぶこと (呼び出しの形は Neovide 0.16.2 のソースで確かめた)
      - scoop の導入 (Windows 導入の手順 2) と、ロールバックの手順 7
  - **markdown-preview.nvim と markdown-toc を外し、GitLab プレビュー・img-clip.nvim・GLFM のスニペットを足した変更は、同じ Windows 11 の実機で、置き場所を差し替えた環境で確かめた (2026-09-29)** ([付録](#付録-gitlab-プレビューなどの検証記録-2026-09-29))
    - 確かめたこと:
      - プラグインの導入と `lazy-lock.json` の版 (38 個、lock は 39 行のまま)、Mason の 11 個、`checkhealth` の ERROR が 0 件
      - GitLab プレビューを、GitLab の形の HTML を返す模擬の API と headless の Edge で (送信の条件・ページの描画・ライブの更新・スクロール・近似表示・閉じ込め・トークンを残さないこと)
      - img-clip.nvim を、本物のクリップボードの画像で (`shell` が `powershell` と `pwsh` の両方。クリップボードの中身は退避して戻した)。GLFM のスニペットを blink.cmp の一覧で
      - `<leader>cp` で既定のブラウザ (Edge) が開いてページがつながること、止めて開き直すと同じタブがつながり直すこと
      - トークンの節の Windows の手順 3・4・8 を、Windows PowerShell 5.1 の画面に打ち込んで (模擬のトークン。最後に消した)
      - gitlab.com が模擬のトークンを 401 で拒み、近似表示に切り替わってそれ以上送らないこと
      - 本物の GitLab で表示できること (マージの後に、利用者が自分のトークンで `<leader>cp` を押して確かめた)
    - **確かめていないこと**:
      - 本物の GitLab での、記法ごとの見え方 (数式・mermaid・画像・参照などは、模擬の API でだけ確かめた)
      - トークンの節の AlmaLinux 10 の手順 (`HOME` を差し替えて Windows の bash で実行しただけ)
  - **SSH 越しのクリップボード ([SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)) は、x86_64 のコンテナで、tmux を手元の端末の代わりにして確かめた (2026-09-29)** ([付録](#付録-ssh-越しのクリップボードの検証記録-2026-09-29))
    - Neovim 0.12.5 (公式の Linux 版のリリース) にこの設定とプラグイン 38 個を入れ、`SSH_CONNECTION` を付けて tmux の中で起動した。tmux (`set-clipboard on`) が OSC 52 を受けて作るペーストバッファを、手元のクリップボードの代わりに見た
    - 確かめたこと:
      - 変更前は、tmux の中の SSH のシェルで `yy` も `"+yy` も OSC 52 を出さない (`clipboard` が空で、tmux では OSC 52 が検出されず、クリップボードの提供元が無い)
      - 変更後は、`yy`・`"+yy`・矩形・文字単位のヤンクで OSC 52 が出て、日本語を含めて中身が一致する。`p` は待たずに元の形 (行単位・矩形) で貼る
      - まだ何も送っていないときの `p` は、待たずに、前に使ったレジスタから貼る (無ければ `E353`)。`SSH_CONNECTION` が無ければ、OSC 52 を出さない (これまでどおり)
      - [SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 1・2 のブロック (手順 2 は tmux の中で、`yy`・`p`・`:set clipboard?`)
    - 実物の WezTerm と AlmaLinux 10 での通しは、次の記録で確かめた
  - **SSH 越しのクリップボードは、AlmaLinux 10 の実機で、WezTerm の nightly から ssh して通した (2026-09-29)** ([付録](#付録-almalinux-10-の実機での-ssh-越しのクリップボードの検証記録-2026-09-29))
    - AlmaLinux 10.2 (x86_64) の上で、WezTerm 20260928 (nightly。利用者の設定ファイルのまま) を画面の無い mutter 49.4 で動かした
    - その WezTerm から sshd に ssh し、ログインしたシェルに[SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)の**手順 1・2 のブロックをそのまま貼って**通した
    - 確かめたこと:
      - 手順 1 の出力 (`SSH_CONNECTION` の 4 つの値と `OSC 52 (copy only)`)、手順 2 の `yy`・`p`・`:set clipboard?`
      - 続けて 5 回ヤンクしても、毎回その内容が手元のクリップボードに入ること
      - 大きな範囲の `ggyG` (日本語の 8 万行、6.9 MB まで) が、ファイルとバイト単位で一致すること。矩形・文字単位の形
      - 変更前は `yy` が入らず、`"+p` が 10 秒待って失敗すること (`"+yy` は入る。WezTerm の nightly は DA1 に `52` を出すので、noice があっても検出される)
    - **確かめていないこと**:
      - Windows の WezTerm と、Windows Terminal など WezTerm 以外の端末
      - GNOME にログインした画面の WezTerm (同じ版の mutter を、画面無しで動かして代えた)
      - PAM を通すシステムの sshd でのログイン (同じ `/usr/sbin/sshd` を、検証用の設定で自分のユーザーのまま立てた)
  - **取り込みの手順 1 は、AlmaLinux 10 の実機で、使っている設定とプラグインに対して行った (2026-09-29)**
    - aa95dab から、#34 と #35 を取り込んだ。このマシンには、#30 で足した img-clip.nvim がまだ入っていなかった
    - ブロックと同じコマンドを、端末に貼る代わりにシェルから実行した。始める前に、このマシンで lock が書き換わっていた (外したプラグインの行が 3 行増えていた) ので、`checkout` で戻した
    - 確かめたこと:
      - 1 回目の `restore` は、起動時に img-clip.nvim を入れたときに lock が古い版で書き直され、更新した 6 個が古い版のまま、`git status --short` が `M lazy-lock.json` を出した
      - lock を `checkout` で戻して `restore` をもう一度実行すると、`git status --short` は何も出さず、38 個 (無効にした render-markdown.nvim 以外) が lock の版に揃った
      - 節のリードの `:Lazy clean` (4 個のディレクトリを消した) と `:MasonUninstall markdown-toc` を headless で実行しても、lock は変わらなかった。`checkhealth lazyvim luamigemo` の ERROR は 0 件
  - **AlmaLinux 10 の実機 (GNOME) では、導入済みの PC で、AlmaLinux 導入の手順 16〜19 と取り込みの手順 1 を通した (2026-09-29)。手順 1〜15 は、システムを変えずに到達点を確かめただけ** ([付録](#付録-almalinux-10-の実機での導入と取り込みの検証記録-2026-09-29))
    - 手順 1〜15 は、確認のコマンド (`rpm -q`・`command -v`・`fc-match`・`gsettings get` など) だけを実行した。dnf と brew の導入・退避・`~/.bashrc` への追記は実行していない
    - 確認の `gsettings get` は Homebrew の `gsettings` (dconf を使わない) を読んでいて、手順 15 は dconf に入っていなかった。利用者の本物のキーでの確認で見つけ、`/usr/bin/gsettings` で手順 14・15 を入れ直した (手順 13〜15 とロールバックのブロックを `/usr/bin/gsettings` に直した)
    - 手順 6・16〜19 は、`XDG_CONFIG_HOME` などを一時的な場所に差し替え、文書のブロックのパスだけを変えて通した。画面の要る手順は tmux の中で起動し、キーを送って状態を読んだ
    - 取り込みの手順 1 は、差し替えた環境で、変更がある状態 (ca6adf3 → ea7bea7。lock の 6 行) を通した。常用の環境では、上の取り込みの後に `Already up to date.` の状態で通した
    - 確かめたこと:
      - `lazy-lock.json` の版に揃うこと (38 個)、Mason の 10 個 (tree-sitter の CLI が PATH にあるため。手順どおりなら 11 個)、treesitter のパーサー 30 個とハイライト、`checkhealth` の ERROR と WARNING が 0 件
      - AlmaLinux 導入の手順 19 の全項目を、本物の ibus-anthy で (カーソルのすぐ下の表示・検索中の表示・コマンドラインのカーソル色と、終了すると起動前の engine に戻ること)。キーは Neovim に直接送った (IBus を通らない)
      - 外から engine を切り替えたときの lualine の追従 (Super+Space の代わりに `busctl` で)
      - LSP の 6 つ、flash の `s`、`*`、GLFM のスニペット、img-clip.nvim の画像の貼り付け (`wl-clipboard`)、GitLab プレビューの近似表示と閉じ込め、既定のブラウザ (Firefox) でページがつながること
      - 常用の環境で、取り込みの手順 1・`:Lazy clean`・`:MasonUninstall markdown-toc` の後に、残骸が無く、起動してもエラーが出ないこと
      - 画面での、ピッカーのアイコンの字形と Firefox のプレビューの表示 (利用者が WezTerm と Firefox で見て確かめた)
      - 利用者が WezTerm (tmux なし) で本物のキーを打って: 手順 15 を入れ直した後は、日本語のときも `<C-j>` で毎回 `あ` / `A` が切り替わり、カーソルのすぐ下にも出ること
      - [上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)の拡張を、画面の無い gnome-shell 49.4 (閉じたセッションバスと自前の ibus-daemon) で。外から engine を切り替えるたびに、今の入力ソースが付いてきた
    - **確かめていないこと**:
      - 手順 1〜15 の実行と、ログインし直しての ibus の読み直し
      - 上部バーの節を、本物のログインで通すこと (拡張を入れて有効にしたが、ログインし直していない)。本物の Super+Space で空振りしなくなること
      - Super+Space で切り替えたときの、カーソルのすぐ下の表示 (フォーカスが戻ったときに出すように直した。本物のキーでは確かめていない)
      - 画面でのカーソルの色の見え方、トークンの節の AlmaLinux の手順と本物の GitLab、tmux の節 (カーソル色)
  - 以前の版の状態行は「AlmaLinux 10 の使い捨てコンテナで手順を頭から流して検証済み」だった。本書はシナリオに分けてコマンドも変えたので、上の記録で置き換える

| 項目 | AlmaLinux 10 | Windows 11 |
|---|---|---|
| 検証 | x86_64 のコンテナ (AlmaLinux 10.2) で通した。GNOME の実機では、手順 16〜19 と取り込みだけを通した | 実機 (Windows 11 Pro) で、置き場所を差し替えて通した |
| パッケージマネージャ | dnf + EPEL、Neovim・lazygit・フォントは Homebrew (7.0.7) | scoop |
| Neovim | Homebrew の `neovim` (0.12.5) | scoop の `neovim` (0.12.5) |
| IME | ibus 1.5.32 + ibus-anthy 1.5.17 (`busctl` / `gdbus` で制御) | zenhan 0.0.1 (任意。検証ではモック) |
| フォント | Homebrew の cask `font-hackgen-nerd` (2.10.0) | リリースの zip から手で入れる |
| 設定の置き場所 | `~/.config/nvim` | `%LOCALAPPDATA%\nvim` |

> [!NOTE]
> - 本書には変数が無い。設定の置き場所と clone 元の URL は、Neovim と GitHub が決める固定の値なので、コマンドに直接書いてある
> - 途中で作る値は `ANTHY_SHORTCUT` だけ ([AlmaLinux 導入の手順 14](#almalinux-10-に導入する-1-度だけ) で作り、手順 15 で使う)
> - 出力例の中のユーザーのホームは `…` で省いてある。パスワードと鍵は扱わない。トークンは [GitLab プレビューのトークンの節](#gitlab-プレビューのトークンを設定する-任意)でだけ扱い、貼った後に入力させる (文書には書かない)

### 実施前の状態

| 項目 | 状態 |
|---|---|
| OS | AlmaLinux 10 + GNOME (Wayland) / Windows 11 |
| ユーザー | AlmaLinux 10 は `sudo` のできる一般ユーザーで、GNOME にログインしている。Windows 11 は一般ユーザー |
| ネットワーク | github.com・Homebrew・npm・scoop に届く (初回のプラグイン・Mason・treesitter の取得に要る)。GitLab プレビューには、使う GitLab と cdn.jsdelivr.net も |
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
| curl / tar / gzip / unzip | treesitter と Mason の取得・展開。curl は GitLab プレビューが GitLab の API を呼ぶのにも使う (8.3 以上) | 必須 (Windows 11 は同梱の curl と tar だけでよい。[Windows 導入の手順 6](#windows-11-に導入する-1-度だけ) の補足) |
| [Node.js](https://nodejs.org/) (node + npm) | Mason が npm で入れる LSP・整形ツール | 必須 |
| Nerd Font ([HackGen Console NF](https://github.com/yuru7/HackGen)) | アイコン表示と `guifont` | 実質必須 (無いと記号が豆腐になる) |
| ibus + ibus-anthy、`busctl` か `gdbus` | 日本語入力 (Linux)。global engine を切り替える | Linux で必須 |
| [zenhan](https://github.com/iuchim/zenhan) または im-select | 日本語入力 (Windows) | 任意 (無ければ IME 連携のみ無効) |
| [Neovide](https://neovide.dev/) 0.16 以上 | GUI クライアント。IME の未確定文字列の表示には Neovim 0.12 以上も要る | 任意 (端末で使うなら不要) |
| lazygit | `<leader>gg` | 任意 (無ければキーマップが定義されないだけ) |
| GitLab の個人アクセストークン (`read_api`) | GitLab プレビューで、GitLab 本体に描かせる ([トークンの節](#gitlab-プレビューのトークンを設定する-任意)) | 任意 (無ければ近似表示になる) |
| ブラウザ | GitLab プレビューのページ | 任意 (プレビューを使うときだけ) |
| wl-clipboard (`wl-paste`) | `<leader>ci` での画像の貼り付け (Linux) | 任意 (無ければ `<leader>ci` だけが使えない) |
| GNOME Shell 49 | [上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)の拡張 (上部バーと Super+Space の順番を Neovim の IME の切り替えに合わせる) | 任意 (無ければ上部バーが Neovim の切り替えに付いてこないだけ) |
| OSC 52 の書き込みに対応した端末 (WezTerm の nightly など) | SSH 越しのヤンクを手元のクリップボードに入れる ([SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)) | 任意 (SSH で使うときだけ) |
| ネットワーク | 初回のプラグイン取得、Mason、treesitter のパーサー。GitLab プレビューでは GitLab と cdn.jsdelivr.net | 初回のみ必須 |

- **不要なもの**: fzf (ピッカーは snacks.nvim の Lua 実装。`:checkhealth lazyvim` が警告を出すが機能には影響しない)、telescope とその C ビルド、make、Python、Deno、win32yank (Neovim の Windows ビルドに同梱済み)、プレビュー用の node のアプリ (GitLab プレビューは Neovim の中の HTTP サーバーと curl だけで動く)、SSH 越しのクリップボードのための X11 転送・xclip・lemonade (OSC 52 で端末に渡す)

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
- **GitLab プレビューの設定は環境変数にする**: 名前は GitLab の CLI (glab) と同じ `GITLAB_TOKEN` / `GITLAB_HOST`
  - この設定のファイル (git で追跡し、ほかのマシンにも配る) にトークンを書かないため
  - トークンと URL は文書に書かず、貼った後に入力させる ([トークンの節](#gitlab-プレビューのトークンを設定する-任意))
- **SSH 越しのクリップボードは OSC 52 にし、向きは Neovim → 手元だけにする** ([SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)): 端末が運ぶので、手元にも AlmaLinux 10 にもソフトを足さずに済む
  - X11 転送 (`ssh -X` と xclip) は、手元に X サーバーが要る。lemonade などの中継は、転送したポートを同じサーバーのほかのユーザーも使える
  - 手元 → Neovim の向きには OSC 52 の読み出しが要るが、WezTerm (nightly を含む) と Windows Terminal は応えない。端末の貼り付けで足りるので扱わない
  - Neovim が OSC 52 を自動で選ぶのは `clipboard` が空のときだけで、`"+y` のように明示したときしか入らない。`y` でも入れるため、`lua/config/options.lua` で明示して `unnamedplus` にする
  - 明示すれば、端末の検出にも頼らない。WezTerm の nightly は DA1 に `52` を出すので検出されるが、出さない端末では XTGETTCAP の応答頼みになり、noice がその応答を受け取らせない (folke/noice.nvim#1229)

### 完了時点の状態

| 場所 | 中身 |
|---|---|
| `~/.config/nvim` (`%LOCALAPPDATA%\nvim`) | このリポジトリの clone (`custom` ブランチ) |
| `~/.local/share/nvim/lazy` | プラグイン 38 個 (`lazy-lock.json` の版)。コンテナで 189 MB (markdown-preview.nvim を img-clip.nvim に替える前の計測) |
| `~/.local/share/nvim/mason` | Mason のツール 11 個。コンテナで 279 MB (markdown-toc を外す前の 12 個での計測) |
| `~/.local/share/nvim/site/parser` | treesitter のパーサー (初回起動で入る) |
| `~/.local/share/fonts` | HackGen Console NF と HackGen35 Console NF (Linux) |
| `~/.bashrc` | `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"` の 1 行 (Linux)。トークンの節を行ったときは `GITLAB_TOKEN` (と `GITLAB_HOST`) の行も |
| `org.gnome.desktop.input-sources sources` | `[('xkb', 'us'), ('ibus', 'anthy')]` (Linux) |
| `org.freedesktop.ibus.engine.anthy.shortcut default` | `on_off` が `['Zenkaku_Hankaku']` だけ (Linux) |
| `~/.local/share/gnome-shell/extensions/ibus-engine-follow@ryo-aoki-pc.github.com` | [上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)を行ったとき、`~/.config/nvim/gnome-shell/` の拡張へのつなぎ。`org.gnome.shell enabled-extensions` にも入る (Linux) |
| `*.bak` | 退避した以前の設定とデータ (あった場合だけ) |

- Windows のプラグインと Mason のツールは `%LOCALAPPDATA%\nvim-data` に入る
- Windows でトークンの節を行ったときは、ユーザーの環境変数に `GITLAB_TOKEN` (と `GITLAB_HOST`) が入る

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
- **保存しても Markdown が整形されない / lint が出ない**: `markdownlint-cli2` は npm のパッケージ
  - node を入れ替えたり消したりすると、Mason で入れたものごと壊れる
  - `:Mason` で状態を見て、`:MasonInstall markdownlint-cli2` で入れ直す
- **GitLab プレビュー (`<leader>cp`) が `近似表示` になる**: ページの上のバナーに理由が出る
  - `GITLAB_TOKEN が未設定`: [トークンの節](#gitlab-プレビューのトークンを設定する-任意)を行い、端末 (と Neovide) を開き直す
  - `トークンが拒否された (HTTP 401)`: トークンの期限切れ、スコープ (`read_api`)、`GITLAB_HOST` の違いを確かめる。直したら `:GitLabPreview` で送り直す
  - `GitLab の API が見つからない (HTTP 404)`: `GITLAB_HOST` が GitLab を指していない。サブパスで動かしている GitLab は `https://example.com/gitlab` まで書く
  - `GitLab に接続できない (curl: …)`: ネットワーク・プロキシ (curl は `HTTPS_PROXY` を見る)・社内の CA (Windows の curl は OS の証明書ストアを使う) を確かめる。30 秒たつと送り直す
  - `option --variable: is unknown` を含むとき: curl が 8.3 より古い。Linux では新しい curl を入れる
- **GitLab プレビューで `#123` などがリンクにならない**: git の remote (origin) のホスト名が `GITLAB_HOST` と違うと、プロジェクトを付けずに描かせる
  - SSH の設定の別名 (`Host` の名前) を使った remote は、ホスト名が一致しない。`git remote -v` で確かめる
- **`<leader>ci` で画像を貼り付けられない**: `:ImgClipDebug` で、使ったコマンドと出力を見る
  - Linux では `wl-clipboard` が要り、Wayland のセッションで起動した Neovim だけが使える (tmux の中では `WAYLAND_DISPLAY` が引き継がれないことがある)
  - `Content is not an image.` は、クリップボードの中身が画像ではないとき。Windows では、PC のロック中はクリップボードを読めない
- **SSH 越しにヤンクしても手元のクリップボードに入らない**: [SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 1 で、`SSH_CONNECTION` と `OSC 52 (copy only)` が出るかを確かめる
  - WezTerm の安定版 (20240203) は、設定ファイル (`~/.wezterm.lua` など) があると OSC 52 を捨てる (wezterm#5917)。nightly にする
  - GNOME Terminal と Ptyxis (どちらも VTE) は OSC 52 に対応していない。AlmaLinux 10 の GNOME から ssh するときも、WezTerm などを使う
  - tmux の中の Neovim では、tmux の `set-clipboard` の既定 (`external`) がアプリの OSC 52 を捨てる。この文書では扱わない (`set -g set-clipboard on` が要る)
  - `sudo -i` や `su -` の後のシェルには `SSH_CONNECTION` が無いので、この設定は OSC 52 を使わない
- **`/` からの日本語検索が効かない**: `:checkhealth luamigemo` で、同梱の辞書と LuaJIT を確かめる
  - ローマ字として読めない入力 (`search` のような英単語、空白や記号を含むもの) は、わざと変換しない
  - まず `/kensaku` のような純粋なローマ字で試す
  - `<Tab>` で候補が出ないときは、ローマ字が 3 文字以上か、`rg` が PATH にあるかを確かめる (候補の照合は ripgrep に任せている)
- **アイコンが豆腐 (□) になる**: 端末のフォントが Nerd Font になっていない。`guifont` は GUI クライアント専用で、端末には効かない
- **全角記号を含む行の桁がずれる**: Neovim の `ambiwidth` と、端末の East Asian Ambiguous の幅の設定が食い違っている
  - この設定は両方を narrow 側 (`single` / `treat_east_asian_ambiguous_width_as_wide=false`) に揃えてある。端末側だけを wide にしない
- **`lazy-lock.json` が勝手に変わる**: `:Lazy sync` / `:Lazy update` は最新に上げる。揃えるだけなら `:Lazy restore`
  - 初めてのマシンの初回起動でも変わる ([AlmaLinux 導入の手順 16](#almalinux-10-に導入する-1-度だけ) の補足)
- **日本語のときに `<C-j>` で英数に戻らない (Linux)**: Anthy の `on_off` に `Ctrl+J` が残っていて、Neovim に届く前に Anthy の中のひらがなと英字が切り替わっている
  - 打った英字が、そのまま出たり「あ」になったりと、日本語の中で入力が揺れるのが特徴
  - AlmaLinux 導入の手順 13〜15 を Homebrew の `gsettings` で実行すると、dconf ではなく `~/.config/glib-2.0/settings/keyfile` に書かれて効かない (手順 13 の補足)
  - `/usr/bin/gsettings` で確かめ、`Ctrl+J` が残っていれば手順 14・15 を貼り直す (今の手順は `/usr/bin/gsettings` を使う)

  ```bash
  /usr/bin/gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | grep -o "'on_off': <\[[^]]*\]>"
  ```

- **GNOME の上部バーが Neovim の `あ` / `A` とずれる・最初の Super+Space が空振りする**: GNOME Shell は、Neovim が切り替えた engine に上部バーを合わせない
  - [上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)の拡張を入れると揃う。入れない場合は、Neovim の中では `<C-j>` を使う (README の補足)
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
- [GitLab の Markdown API](https://docs.gitlab.com/api/markdown/): GitLab プレビューが呼ぶ API。認証が要ること (`read_api` で足りる) と `project` の扱い
- [GitLab Flavored Markdown](https://docs.gitlab.com/user/markdown/): GLFM の記法 (スニペットと近似表示が扱う記法の出どころ)
- [GitLab の個人アクセストークン](https://docs.gitlab.com/user/profile/personal_access_tokens/): トークンの作り方とスコープ
- [img-clip.nvim](https://github.com/HakonHarnes/img-clip.nvim): 画像の貼り付けの設定項目
- [Neovim の clipboard-osc52](https://neovim.io/doc/user/provider/#clipboard-osc52): OSC 52 の提供元と、自動検出が効く条件 (`clipboard` が空のときだけ)
- [wezterm#5917](https://github.com/wezterm/wezterm/issues/5917): 設定ファイルがあると OSC 52 が効かない (nightly で直った)
- [folke/noice.nvim#1229](https://github.com/folke/noice.nvim/issues/1229): noice が XTGETTCAP の応答を受け取らせず、DA1 に `52` を出さない端末では OSC 52 の自動検出が効かない
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

### 付録: GitLab プレビューなどの検証記録 (2026-09-29)

- **対象**: markdown-preview.nvim と markdown-toc を外し、GitLab プレビュー・img-clip.nvim・GLFM のスニペットを足した変更
- **環境**: 上の付録と同じ Windows 11 の実機。`LOCALAPPDATA` / `TEMP` を `%TEMP%\nvv-gp` の下に差し替え、PATH はレジストリの Machine の値と、手順書で scoop が入れるアプリのディレクトリだけにした (scoop の shims は含めないので、curl は System32 の 8.21.0)
  - この設定は robocopy で写した。テストの nvim は `set clipboard=` で起動し、クリップボードに書かないようにした
  - 最初は置き場所を深いディレクトリにして、git の clone が `Filename too long` で失敗した。このとき lazy.nvim の bootstrap はキー入力を待つので、headless では返ってこない。短い場所に置き直した
- **プラグインと lock** (Windows 導入の手順 8 と同じ操作): 1 行目は 17 秒。lock の差分は、既知の 6 行 (SchemaStore.nvim など) と img-clip.nvim の追加だけだった
  - img-clip.nvim の行 (99848da) を足した lock に restore すると、`lazy/` は 38 個で、lock は変わらなかった
  - markdown-preview.nvim のディレクトリはできず、gitlab-preview (virtual の spec) もディレクトリを作らなかった
- **設定の合成** (headless での 83 項目): conform の markdown は `markdownlint-cli2` だけ、`markdown.mdx` は `prettier` と `markdownlint-cli2`。Mason の `ensure_installed` に markdown-toc は無く、`stylua` などは残った
  - `:GitLabPreview*` と `:PasteImage` があり、`<leader>cp` / `<leader>ci` は markdown のバッファにだけ張られた
  - スニペットの 21 個は、どれも Neovim のスニペットの文法で読めた。blink.cmp の一覧に `gl*` が全部入り、friendly-snippets のものも残った
  - ファイルの閉じ込め (`resolve()`): `..`・`%2e%2e`・`%5c`・ドライブ・`%00`・`.git`・`CON`・末尾の `.`・外を指すジャンクションを拒んだ
  - 最初は virtual の spec を `name` だけで書き、lazy.nvim に `Invalid plugin spec` として捨てられていた。名前を `[1]` に書いて直した
- **Mason**: 11 個 (`bash-language-server` / `json-lsp` / `lua-language-server` / `markdownlint-cli2` / `marksman` / `shellcheck` / `shfmt` / `stylua` / `taplo` / `tree-sitter-cli` / `yaml-language-server`) が入り、markdown-toc は入らなかった
  - headless では mason-lspconfig が LSP のサーバーを入れない (`platform.is_headless` で飛ばす) ので、その `ensure_installed` を直接呼んで数えた
  - `checkhealth lazyvim` は ERROR 0 件、WARNING は `fzf` の 1 件
- **GitLab プレビュー** (87 項目): node で GitLab の形の HTML を返す模擬の Markdown API を立て、headless の nvim を `--listen` で操作し、headless の Edge 154 を CDP で見た
  - トークンが無いと、API に 1 回も送らずに近似表示になった。トークンを入れて `:GitLabPreview` を打つと、`project`・`gfm`・`PRIVATE-TOKEN` を付けて送り、返った HTML のまま描いた
  - ページ: mermaid の SVG と KaTeX。`data-canonical-src` から手元の画像 (`../img/a.png`、日本語と空白の名前) を出し、`/uploads/` は GitLab から読んだ。リポジトリへのリンクは GitLab の URL のまま新しいタブで開いた
  - TOC・アラート・`[~]`・inline diff・色見本が出た。ライト / ダークが切り替わり、CSP の違反と例外は 0 件だった
  - 打つと約 1 秒で描き直され、カーソルの移動にスクロールが付いてきた。10 回続けて編集しても、送ったのは 1〜2 回
  - 別の .md に移ると追従し、戻ると送り直さずに前の結果を出した。遅い応答の途中でバッファを移ると、古い応答は出さなかった
  - 401 の後は送らなかった。プロジェクトの 404 では、プロジェクトを外して 1 回だけ送り直した。remote のホストが違えば `project` を付けなかった
  - API を止めると近似表示になり、送らない時間 (検証では 30 秒を 2.5 秒に縮めた) の後に戻った。cdn.jsdelivr.net を塞ぐと、近似表示では原文をそのまま出した
  - サーバーは、token の違う URL・Host の偽装・`Sec-Fetch-Site: cross-site`・POST を拒んだ。画像には ETag で 304 を返した
  - 送信中の curl のコマンドラインにトークンの値は無く (`--variable %GITLAB_TOKEN`)、TEMP のファイルにも残らなかった
  - 止めるとページに「止めた」が出て接続が閉じ、開き直すと同じ URL に戻った。Neovim の終了もページに届いた
- **img-clip.nvim**: `checkhealth img-clip` は OK。`shell` は `powershell` (5.1) で、img-clip と同じ経路 (`vim.fn.system()`) で PowerShell を実行でき (STA)、日本語と空白を含むパスに画像を保存できた
  - クリップボードの読み出しと保存を差し替えて `:PasteImage` を通すと、`docs/assets/<日時>.png` に保存し、`![](assets/<日時>.png)` を入れた (ファイル名の入力は空)
  - 祖先のディレクトリに置いた `.img-clip.lua` は、設定の参照・貼り付け・`vim.paste` のどれでも実行されなかった。`vim.paste` はただの文字列として入った
  - クリップボードそのものは、PC のロック中で Windows が開かせなかった (`Requested Clipboard operation did not succeed.`。この設定と関係の無い PowerShell からも同じ)
- **手順書のブロック**: トークンの節の PowerShell の 4 個は、Windows PowerShell 5.1 と PowerShell 7.6.6 のパーサーでエラーが無く、`&&` / `||` も無かった
  - bash の 4 個は `bash -n` を通した。Windows の bash で `HOME` を差し替えて実行し、記号を含むトークンが `~/.bashrc` を通してそのまま戻ること、2 回実行しても 1 行だけになること、消せることを確かめた
- **ロックを解いた後の確認** (同じ日、同じ置き場所の差し替えで):
  - 本物のクリップボードの画像: 先にクリップボードの中身 (text/html・HTML Format・UnicodeText・Text) をファイルに退避し、64×40 の画像を置いた
    - `<leader>ci` → ファイル名は空のまま Enter で、`docs/assets/<日時>.png` に同じ大きさ・同じ色の PNG ができ、`![](assets/<日時>.png)` が入った
    - `shell` が `powershell` (5.1) でも、`pwsh` (7.6.6。PATH に本物の `pwsh.exe` を載せた) でも同じだった
    - 終わった後にクリップボードの中身を戻し、文字列のハッシュと 4 つの形式が元どおりなことを確かめた。Windows のクリップボードの履歴には、試験の画像が残る
  - 既定のブラウザ: `vim.g.gitlab_preview_browser` を付けずに `:GitLabPreview` を打つと、`vim.ui.open` が 1 回呼ばれて Edge (既定のブラウザ) にタブが開き、そのタブの EventSource がつながった
    - `:GitLabPreviewStop` の後に `:GitLabPreview` を打つと、同じ URL で開き、開いたままのタブがつながり直した。新しいタブは開かなかった
  - トークンの節の Windows の手順 3・4・8: headless の nvim の `:terminal` (ConPTY) で Windows PowerShell 5.1 を開き、文書のブロックをそのまま打ち込んだ。トークンは模擬の値で、始める前に `GITLAB_*` のユーザーの環境変数が無いことを確かめた
    - 手順 3 は `GitLab のトークン: ` を出して入力を `*` で隠し、`HKCU\Environment` に `GITLAB_TOKEN` が入った。値は画面に出なかった
    - 手順 4 は URL を入れると `GITLAB_HOST` が入り、空のまま Enter で消えた。手順 8 で 2 つとも消えた
    - `SetEnvironmentVariable(…, 'User')` は 1 回 2 秒ほどかかった (変えたことを全てのウィンドウに知らせ終わるまで戻らない)。プロンプトが戻る前に次を打つと待たされるので、手順の箇条書きに書いた
  - gitlab.com: 模擬のトークンで Markdown API を呼ぶと、`401` と `{"message":"401 Unauthorized"}` が返った (Cloudflare の 403 ではない)。プレビューは `トークンが拒否された (HTTP 401)` の近似表示になり、その後の編集では curl を呼ばなかった
- **本物の GitLab** (マージの後): 利用者が自分のトークンを設定して `<leader>cp` を押し、GitLab が描いた表示でプレビューが出ることを確かめた。どの記法を見たかは記録していない

#### 未確認事項 (GitLab プレビューなど)

- 本物の GitLab での、記法ごとの見え方と、GitLab の版による HTML の違い (`data-canonical-src`・アラート・`data-sourcepos`)
- 非公開のプロジェクトの `/uploads/` の画像、`::include`、PlantUML / Kroki の図
- Linux での画像の貼り付け (`wl-clipboard`、Wayland と tmux)
- AlmaLinux 10 での、この変更の後の通し (`wl-clipboard` の導入、トークンの節の AlmaLinux の手順)

### 付録: SSH 越しのクリップボードの検証記録 (2026-09-29)

- **対象**: SSH のシェルで起動したときに、ヤンクを OSC 52 で手元のクリップボードに送る変更 (`lua/config/options.lua`) と、[SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)
- **環境**: x86_64 のクラウドのコンテナ (AlmaLinux ではない)。Neovim 0.12.5 は公式の Linux 版のリリース (`nvim-linux-x86_64.tar.gz`)、tmux 3.4
  - この設定を一時的な `XDG_CONFIG_HOME` に clone し、AlmaLinux 導入の手順 16 と同じ操作でプラグイン 38 個を入れた (`git status --short` は空)
  - 手元の端末の代わりに tmux を使った。`set-clipboard on` の tmux は、中のアプリが出した OSC 52 をペーストバッファにする。`env -u TMUX` と `SSH_CONNECTION` を付けて nvim を起動し、キーは `send-keys` で送った
  - SSH のサーバーは立てていない。この設定が見るのは `SSH_CONNECTION` だけなので、環境変数で代えた
- **変更前** (`custom` の aa95dab): `yy` の後も `"+yy` の後も、ペーストバッファはできなかった
  - `clipboard` は空、`provider#clipboard#Executable()` は空 (クリップボードの提供元が無い)、`g:termfeatures` は `{}` (OSC 52 が検出されていない)
- **変更後**:
  - `yy` で、ペーストバッファが `SSH 越しのヤンクを試す。` と改行 (UTF-8 のまま) になった。`"+yy` も同じ
  - `p` はすぐに同じ行を下に貼り、`getregtype('+')` は `V` だった。矩形 (`<C-v>`) のヤンクは `\0222` で、`p` で矩形のまま貼れた。`yiw` は `v`
  - ShaDa も送ったものも無い状態の `p` は、`E353: Nothing in register "` を出してすぐ戻った。ShaDa がある状態では、前回の起動のレジスタから貼った (Neovim の `get_yank_register()` が、提供元が失敗したときに直前のレジスタを使う)
  - `clipboard` は `unnamedplus`、`provider#clipboard#Executable()` は `OSC 52 (copy only)` だった
  - `SSH_CONNECTION` を外すと、`g:clipboard` は無く、`yy` でペーストバッファはできなかった (これまでどおり)
  - `nvim --headless` は、`SSH_CONNECTION` の有無のどちらでもエラーを出さなかった
- **手順書のブロック**: 手順 1・2 のブロックを `bash -n` に通し、手順 1 は `SSH_CONNECTION` の有無で `OSC 52 (copy only)` / `(無い)` を出した。手順 2 は tmux の中で打ち、`yy`・`p`・`:set clipboard?` が書いたとおりになった
- **調べて分かったこと** (本文と方針に入れた):
  - LazyVim は `SSH_CONNECTION` があると `clipboard` を空にする。Neovim 0.12.5 の `provider/clipboard.vim` は、`clipboard` が空で `g:termfeatures.osc52` が立っているときだけ OSC 52 を自動で選ぶ
  - 検出 (`runtime/plugin/osc52.lua`) は DA1 に `52` が無ければ XTGETTCAP の `Ms` を問い合わせる。noice が messages / cmdline を扱っている間はその応答が届かない (folke/noice.nvim#1229)
  - Neovim の OSC 52 の読み出しは、応答が無いと 1 秒待ってから、さらに 9 秒待つ。WezTerm (読み出しは未マージの PR だけ) と Windows Terminal は応えない

#### 未確認事項 (SSH 越しのクリップボード)

- 実物の WezTerm (nightly) と ssh で、手元のクリップボードに入ること。日本語と、大きな範囲 (`ggyG` など) の送り方
- AlmaLinux 10 での通し (SSH のサーバーと、ログインしたシェルの `SSH_CONNECTION`)
- Windows Terminal など、WezTerm 以外の端末

### 付録: AlmaLinux 10 の実機での SSH 越しのクリップボードの検証記録 (2026-09-29)

- **対象**: 上の付録と同じ変更 (20cf960)。上の付録の未確認事項のうち、実物の WezTerm と AlmaLinux 10 での通し
- **環境**: AlmaLinux 10.2 (x86_64) の実機。Neovim 0.12.5 (Homebrew)、WezTerm 20260928_051827_7a370108 (nightly の RPM)、mutter 49.4、OpenSSH 9.9p1
  - 利用者の GNOME の画面とクリップボードに触れないよう、専用のセッションバスの中で `mutter --headless --wayland --no-x11` を起動し、その上で WezTerm を動かした
  - WezTerm の設定は、利用者の `~/.config/wezterm` のまま (設定ファイルがあると OSC 52 を捨てる wezterm#5917 の条件)
  - クリップボードは、その mutter の RemoteDesktop の D-Bus (`EnableClipboard` / `SelectionRead`) で読んだ。seat にキーボードを持たせるため、同じ API の仮想キーボードを使った
  - sshd は、同じ `/usr/sbin/sshd` を自分のユーザーのまま `127.0.0.1:2222` に立てた (検証用の鍵と設定、`UsePAM no`)。システムの sshd の設定と `~/.ssh` は変えていない
  - この設定は PR のブランチを worktree に置き、ssh したシェルで `XDG_CONFIG_HOME` などを一時的な場所に向けた。プラグインは `~/.local/share/nvim` を写し、`Lazy! restore` で lock に揃えた
  - 最初は一時的な場所のパスが長く、`vim.loader` のキャッシュのファイル名が上限を超えて (`ENAMETOOLONG`) `lazyvim.plugins` が読めなかった (noice も入らない)。短いパスに置き直した
- **手順書のブロック**: ssh したシェルに、手順 1・2 のブロックをそのまま貼った
  - ログインしたシェルの `SSH_CONNECTION` は `127.0.0.1 51210 127.0.0.1 2222`、`TERM` は `xterm-256color` で、`TMUX` は無かった。手順 1 の 2 行目は `OSC 52 (copy only)` だった
  - 手順 2 の `yy` で、クリップボードが `SSH 越しのヤンクを試す。` と改行 (35 バイト、UTF-8) になった
  - `p` は 0.02 秒で同じ行を下に貼り、`:set clipboard?` は noice の窓に `clipboard=unnamedplus` を出した
  - Neovim の中では noice が読み込まれ、`g:termfeatures` は `{ osc52 = true }`、クリップボードの提供元は `OSC 52 (copy only)` だった
- **変更後** (キーは仮想キーボードで WezTerm に打った):
  - 違う文の 5 行を、1 行ずつ `yy` で 5 回続けてヤンクすると、毎回その行がクリップボードに入った
  - `ggyG` で、日本語の 2,000 行 (170,893 B)・2 万行 (1,728,894 B)・8 万行 (6,948,894 B) のファイルが、ファイルとバイト単位で一致した
  - 矩形 (`<C-v>`) は `A \nB \nC ` で、`getregtype('+')` は `\0222`。`p` で矩形のまま貼れた。`yiw` は `回目` だけが入った
  - ShaDa の無い新しい状態で、何も送らずに `p` を押すと、1 秒以内に `E353: Nothing in register "` を出した
- **変更前** (`custom` の aa95dab。同じ WezTerm と ssh):
  - `yy` では、クリップボードは変わらなかった (`clipboard` は空)
  - noice は読み込まれていたが、`g:termfeatures` は `{ osc52 = true }` で、`"+yy` はクリップボードに入った
  - `"+p` は 10.3 秒待ってから `Timed out waiting for a clipboard response from the terminal` を出した (WezTerm は OSC 52 の読み出しに応えない)
- **調べて分かったこと** (本文・方針・README・`lua/config/options.lua` のコメントを直した):
  - WezTerm の nightly は DA1 に `\E[?65;4;6;18;22;52c` を返し、XTGETTCAP の `Ms` にも OSC 52 の形を返した。Neovim の検出は DA1 で済むので、noice#1229 (XTGETTCAP の応答が届かない) にかからない
  - 上の付録で変更前の `"+yy` が出なかったのは、手元の端末の代わりにした tmux で OSC 52 が検出されなかったため
  - この変更が要る理由は、`clipboard` が空で `y` が入らないことと、`"+p` の 10 秒の待ち。検出の失敗は、DA1 に `52` を出さない端末でだけ起きる
- **検証の仕方で起きたこと** (この設定の問題ではない):
  - 仮想キーボードを足す前の mutter では、WezTerm が OSC 52 を受けた時点で落ちた (`window/src/os/wayland/copy_and_paste.rs:96` の `unwrap()`。seat にキーボードが無く、データデバイスが無い)
  - キーを `wezterm cli send-text` で pty に直接送ると、Wayland のキー入力が無いので WezTerm の serial が変わらない。mutter は新しくない serial の `set_selection` を無視するので、続けたヤンクが 1 回おきに前の内容のままになった
  - キーを仮想キーボードで打つと serial が毎回新しくなり、起きなかった

#### 未確認事項 (AlmaLinux 10 の実機での SSH 越しのクリップボード)

- Windows の WezTerm (nightly) からの ssh と、Windows Terminal など WezTerm 以外の端末
- GNOME にログインした画面の WezTerm (同じ版の mutter を、画面無しで動かして代えた)
- PAM を通すシステムの sshd でのログイン (`UsePAM no` で、自分のユーザーのまま立てた sshd で代えた)

### 付録: AlmaLinux 10 の実機での導入と取り込みの検証記録 (2026-09-29)

- **対象**: `custom` の ca6adf3 (#34 のマージの直後) と、検証中に入った ea7bea7 (#35。lock の 6 行)。上の付録の未確認事項のうち、GNOME の実機での通し・カーソルのすぐ下の表示・treesitter のパーサー・検索中の表示・AlmaLinux 10 での GitLab プレビューなどの通し・取り込みの手順 1 を変更がある状態で通すこと
- **環境**: AlmaLinux 10.2 (x86_64) の実機、GNOME (Wayland)。常用の端末は WezTerm (フォントは HackGen Console NF) の中の tmux (el10 の 3.3a)
  - AlmaLinux 導入の手順 1〜15 は、この PC で前に済ませてあった。git 2.52.0、gcc 14.3.1、nodejs 22.23.2 (nodejs-npm 10.9.8)、ibus 1.5.32 + ibus-anthy 1.5.17、wl-clipboard 2.2.1、Homebrew 7.0.6 (neovim 0.12.5_1、lazygit 0.65.1)
  - 手順書と違うところ: ripgrep 15.2.0 と fd 10.5.0 は Homebrew で入っていて、dnf の `ripgrep` / `fd-find` は無い。Homebrew の `tree-sitter-cli` 0.27.0・`fzf`・`curl` 8.22.0 も入っている
  - フォントは cask ではなく `~/.local/share/fonts/HackGen` に 2 ファイル (HackGen35 は無い)。`~/.tmux.conf` は無い (tmux の節は行っていない)
- **手順 1〜15 (確認だけ)**: システムを変えるコマンド (dnf と brew の導入、`gsettings set`、`mv`、`~/.bashrc` への追記) は実行せず、確認のコマンドだけを実行した
  - 手順 1 は `epel` の行を出した。手順 4 の `rpm -q` は `ripgrep` と `fd-find` の 2 行が `not installed` で、ほかは入っていた。`node --version` は `v22.23.2`、`command -v` は 5 つとも場所を出した
  - 手順 7・9・11 は `brew` の場所・`brew shellenv` の行・`NVIM v0.12.5` と 2 つの場所。手順 12 の `fc-match` は `HackGenConsoleNF-Regular.ttf: "HackGen Console NF" "Regular"`
  - 手順 13 の `gsettings get` は `[('xkb', 'us'), ('ibus', 'anthy')]`。手順 14 で作った値と手順 15 の `gsettings get` は、どちらも `'on_off': <['Zenkaku_Hankaku']>`
  - ただし、この `gsettings` は PATH の先頭の Homebrew のもので、dconf ではなく `~/.config/glib-2.0/settings/keyfile` (2026-09-21 に作られていた) を読んでいた。dconf の `on_off` は既定のまま `Ctrl+J` を含んでいた (下の「本物のキーでの確認」で見つけた。入力ソースは dconf にも同じ値が入っていた)
  - `which python3` は `/usr/bin/python3` だった (Homebrew の python@3.14 は依存として入っていて、link されていない)
- **差し替えた環境での導入** (手順 6・16〜19):
  - `XDG_CONFIG_HOME` / `XDG_DATA_HOME` / `XDG_STATE_HOME` / `XDG_CACHE_HOME` と npm のキャッシュを一時的な場所に向けて nvim を起動した。IME 連携は ibus のバスを `~/.config/ibus/bus` から引くので、本物の ibus-anthy を使った
  - 画面の要る手順は、専用の tmux サーバーの中で `--listen` を付けて起動し、キーを `--remote-send` で送り、状態を `--remote-expr` で読んだ
  - 手順 6: GitHub から clone して `custom`、ca6adf3
  - 手順 16: 1 行目は 22 秒で、38 個が入った。終わりに `Neovim exited while the following packages were installing` (Mason の 4 個) と `Error in command line` が出た
    - tree-sitter の CLI が PATH にあるので、`Unmet requirements for nvim-treesitter` は出ず、パーサーの取得が始まって終了で打ち切られた
    - lock は既知の 6 行 (SchemaStore.nvim・gitsigns.nvim・mason-lspconfig.nvim・mini.icons・nvim-lspconfig・nvim-treesitter) が変わった。戻して `restore` (1 秒) の後、`git status --short` は空で、38 個とも記録の版だった
  - 手順 17: 開いてから 13 秒で、Mason の 10 個とパーサー 30 個 (`Installed 30/30 languages`) が揃った
    - Mason に `tree-sitter-cli` は入らなかった。LazyVim は PATH に `tree-sitter` があれば Mason で入れない
    - この 1 回だけ、`Error running markdownlint-cli2: ENOENT` の通知が出た (Mason が入れ終わる前に lint が走った)
    - 起動前の engine は `anthy` で、起動で `xkb:us::eng` になり、`:qa` で `anthy` に戻った
  - 手順 18: `grep` は何も出さなかった (fzf が入っているので、`fzf` の WARNING も出ない)
  - 手順 19 (2 回目の起動):
    - `/kensaku` で 3 行目の「検索」に移って `[1/1]`。`/kensaku<Tab>` でコマンドラインが「検索」になった
    - `:w` で `#動作確認` が `# 動作確認` になり、markdownlint の診断が 2 件から 0 件になった (見出しとしてハイライトされる)
    - `o` → `<C-j>` で engine が `anthy`、lualine が `あ` になり、カーソルの 1 行下の同じ桁に `あ` の窓が出て、1.5 秒後には消えていた。`<Esc>` で `xkb:us::eng` と `A` に戻った
    - `/` で最下段の右端に `A` が出た。`<C-j>` で `あ` になり、検索欄のカーソルのすぐ上にも `あ` が出た。カーソル色 (`IMECursor`) は `#ff9e64` になった
    - `<Esc>` の後の `/` は `あ` で始まった (検索の sticky)。`<C-j>` で `A` に戻して抜けた
    - Space 2 回で Files のピッカーとプレビューが開き、アイコンの文字 (Nerd Font の私用領域) が入っていた
  - 追加の確認:
    - ノーマルモードで外から `busctl` で engine を `anthy` → `xkb:us::eng` → `anthy` と 1.5 秒おきに変えると、lualine が `あ` / `A` に追従した
    - flash: `s` → `nihon` → `;` で「日本」の後ろにラベル `s` が出て、`s` で 3 行目の先頭へ飛んだ
    - `*`: 「検索する」の「検索」の上で押すと、`@/` が `\V検索` になり、次の行の「日本語検索」の中へ移った
    - GLFM のスニペット: markdown のスニペット 97 個のうち `gl` で始まる 21 個が、`gl` と打った blink.cmp の一覧に全部出た
    - LSP: marksman・lua_ls・bashls・jsonls・yamlls・taplo がそれぞれのファイルに付き、ハイライトも効いた。markdownlint の MD040 と、bashls 経由の shellcheck の診断が出た
    - img-clip.nvim: `wl-copy` で 64×40 の PNG をクリップボードに置き、`<leader>ci` → ファイル名は空のまま Enter で、`docs/assets/<日時>.png` (画素まで同じ) ができて `![](assets/<日時>.png)` が入った。貼った後は挿入モードになる (img-clip の既定)。クリップボードは空に戻した
    - GitLab プレビュー (`GITLAB_TOKEN` 無し): ページは 200 (CSP 付き)、token 違いは 404、Host の偽装・`Sec-Fetch-Site: cross-site`・`..`・`.git/HEAD` は 403、POST は 405、`%2e%2e` は 404、画像は 200 で ETag を付けると 304
    - SSE は `retry: 1000` と、近似表示 (`GITLAB_TOKEN が未設定`) の `render` を送った。編集すると描き直しが届き、止めると `stop` が届いた。GitLab へは送らなかった
    - `:checkhealth` を全部流すと、ERROR は lazy の luarocks と、snacks の画像の外部ツール (tectonic / pdflatex・mmdc・kitty の画像) だけで、この設定の機能に関わるものは無かった
  - 取り込みの手順 1 (ea7bea7 へ): このホストの常用の環境と同じく、lock に古い 3 行 (denops.vim・vim-kensaku・vim-kensaku-search) を足し、`pull.autostash` を true にして貼った
    - `Created autostash` → `Fast-forward` (lock の 6 行) → `Applied autostash` → `restore` (2 秒) で、`git status --short` は空だった (restore が lock を spec のとおりに書き直し、古い 3 行も消えた)
    - 差し替えた環境には img-clip.nvim が入っていて、起動時に入れるものが無かったので、1 回目の `restore` で揃った (入れるものがあると lock が古い版で書き直される。上の状態の行の取り込みの記録)
    - 38 個とも新しい記録の版で、手順 18 の `grep` は何も出さず、LSP とハイライトも同じだった
- **常用の環境**:
  - 検証の途中で、常用の設定は別の作業 (上の状態の行の取り込みの記録) で ea7bea7 に揃えられていた (img-clip.nvim が入り、lock の古い 3 行も消えた)。このため、変更がある状態の取り込みは、差し替えた環境で確かめた
  - 取り込みの手順 1 のブロックは、`Already up to date.` と `restore` (4 秒) で、`git status --short` は空だった
  - `nvim --headless "+Lazy! clean" +qa` は、外したプラグインの 4 個 (denops.vim・markdown-preview.nvim・vim-kensaku・vim-kensaku-search) だけを消した。`lazy/` は 38 個になり、lock は変わらなかった
  - 画面 (`-i NONE`) で `:MasonUninstall markdown-toc` を打つと、Mason は 10 個になり、`mason/bin` からも消えた
  - 起動してもエラーの通知は無く、パーサーは 30 個のままだった。`/kensaku`・`:w` の整形・`<C-j>` は差し替えた環境と同じだった。`checkhealth img-clip` は、img-clip を読み込んでから流すと `wl-clipboard` が OK だった
  - `<leader>cp` で既定のブラウザ (Firefox 156) にタブが開き、約 1 秒でページの EventSource がつながった
- **利用者の目視** (WezTerm で常用の環境の nvim を開き、AlmaLinux 導入の手順 17 と同じ試験用の Markdown で):
  - Space 2 回のピッカーで、アイコンが豆腐にならずに出た
  - `<leader>cp` で、Firefox のタブに近似表示のプレビュー (上の帯、見出しと本文) が出た
  - 「Super+Space と上部バー」「カーソルのすぐ下の `あ`」は、おかしいという報告だった (次の項目)
- **本物のキーでの確認** (利用者の報告の後。WezTerm で tmux を通さずに起動した nvim に、フォーカス・モード・IME の状態・表示の呼び出し・受け取ったキーを記録させ、利用者に打ってもらった):
  - 日本語のときの `<C-j>` は、3 回とも Neovim に届かなかった。続けて打った `a` は、そのまま `a` で届いたり「あ」で届いたりした (Anthy の中のひらがなと英字が `Ctrl+J` で切り替わっていた)
  - Anthy の設定を Anthy 自身の読み方 (`AnthyPrefs`) で読むと、`on_off` が `['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J']` のままで、dconf にも利用者の値が無かった。手順 13〜15 が Homebrew の `gsettings` で keyfile に書かれていた (Homebrew の glib は cairo・ffmpeg-full・imagemagick-full などの依存で入っていた)
  - `/usr/bin/gsettings` で手順 14・15 を入れ直すと (`Ctrl+J` は `commit` だけに残る。未確定の文字が無ければ Anthy は `Ctrl+J` を通す)、日本語のときも `<C-j>` で毎回 `あ` / `A` が切り替わり、カーソルのすぐ下にも出た (利用者が確かめた)
  - Neovim を開いた時点で上部バーがずれていて、最初の Super+Space では engine が変わらなかった (すでに `xkb:us::eng` だった)。GNOME Shell 49.4 の `ui/status/keyboard.js` と `misc/ibusManager.js` を読むと、外からの engine の変更で「今の入力ソース」と Super+Space の順番 (MRU) を更新しない。そのため[上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)の拡張を足した
  - Super+Space では、GNOME Shell がキーボードを掴むので、WezTerm から FocusLost → engine の切り替え → FocusGained の順で届くことがあった (記録の 23:36:15.715 → 16.198 → 16.200)。カーソルのすぐ下の表示は、フォーカスが外れている間は出さないので、Super+Space の表示が出なかった。`lua/config/ime_indicator.lua` を、外れている間に変わっていたら FocusGained で出すように直した
- **上部バーの拡張の確認**: 画面の無い gnome-shell 49.4 を、閉じたセッションバス (`dbus-run-session`)・一時的な XDG の置き場所・`GSETTINGS_BACKEND=keyfile` で起動し、拡張を有効にして確かめた
  - gnome-shell が自前の ibus-daemon を起動し、拡張は `enabled` になった
  - `ibus engine` で `anthy` → `xkb:us::eng` → `anthy` → `xkb:us::eng` と切り替えると、そのたびに今の入力ソースが `anthy` / `us` に付いてきた (検証用の環境変数で出したログ)
  - ibus は、同じ engine を設定し直してもシグナルを出さなかった (拡張が行き来を起こさない根拠)
  - 利用者の PC には、拡張を worktree へつないで `org.gnome.shell enabled-extensions` に足した (有効になるのは次のログインから)
- **カーソルのすぐ下の表示の直しの確認**: 直した設定を一時的な `XDG_CONFIG_HOME` で起動し、`doautocmd FocusLost` → 外から `anthy` → `doautocmd FocusGained` とすると、戻った時点で `あ` の窓が出た。変化が無いとき・ノーマルモードのときは出ず、フォーカスがあるときの `<C-j>` は今までどおり出た
- **調べて分かったこと**:
  - ノーマルモードで外から `anthy` にした後に、`:qa<CR>` を一度に送ると、engine は `xkb:us::eng` のまま残った。`:` で英数に切り替える要求の完了より先に、終了時の復帰が走る
    - `ZQ` で抜けるか、`:` の後に 0.3 秒おいてから `qa` と打つと、`anthy` に戻った。人の打鍵より速い入力 (マクロや `nvim_input`) でだけ起きる
- **検証の仕方で起きたこと** (この設定の問題ではない):
  - 最初は一時的な場所のパスが長く、`vim.loader` のキャッシュのファイル名が上限の 255 バイトを超えて (`ENAMETOOLONG`)、mason.nvim などのモジュールが読めなかった。手順 16 の 1 行目は、headless では完了まで待つ `:MasonUpdate` が返らず、580 秒で打ち切った。短いパス (`/run/user/<uid>` の下) に置き直すと 22 秒で終わった
  - el10 の tmux 3.3a は、`capture-pane -p` で落ちた (ASCII だけの画面でも)。画面は Neovim の `screenstring()` で読んだ
  - `wl-copy` は常駐してクリップボードを配るので、出力をパイプにつないで呼ぶと、呼び出し元がクリップボードを空に戻すまで終わらない
  - `:checkhealth` を全部流すと、Neovim 0.12 の vim.pack の検査が空の `site/pack/core/opt` を作り、lazy の検査が `found existing packages` と警告する
  - 最初の確認では、キーを RPC で Neovim に直接送ったので IBus を通らず、`Ctrl+J` が Anthy に食われることに気付けなかった
  - 画面の無い gnome-shell は、つながっている USB のボリュームを自動でマウントしようとした (ntfs3 が無くて失敗し、何も変わらなかった)。次に行うときは `org.gnome.desktop.media-handling automount` を false にする

#### 未確認事項 (AlmaLinux 10 の実機での導入と取り込み)

- AlmaLinux 導入の手順 1〜15 の実行 (この PC では済んでいた) と、ログインし直しての ibus の読み直し
- 上部バーの節を本物のログインで通すこと (拡張は入れたが、ログインし直していない)。本物の Super+Space で上部バーと lualine が揃うこと
- Super+Space で切り替えたときの、カーソルのすぐ下の表示 (直しは擬似のフォーカスの出入りで確かめた)
- 画面でのカーソルの色の見え方
- トークンの節の AlmaLinux の手順と、本物の GitLab での表示
- tmux の節 (カーソル色)、JIS 配列のキーボード、aarch64
