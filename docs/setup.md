# Neovim 設定 (LazyVim) の導入手順 (AlmaLinux 10 + GNOME / Windows 11)

## 実施手順

- [検証記録](verification/setup.md)・[背景説明](reference/setup.md)は別ファイルに記載する

> [!IMPORTANT]
> - **AlmaLinux 10 では、GNOME にログインしたデスクトップの端末で、自分のユーザーのまま実行する** ([SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)だけは、手元の WezTerm から ssh したシェルで貼る)。`sudo -i` した root のシェルでは行わない (Homebrew は root で動かず、`gsettings` は実行したユーザーの設定しか変えない)
> - **AlmaLinux 10 で実行するユーザーは `sudo` できる必要がある** ([AlmaLinux 導入の手順 2・3・8](#almalinux-10-に導入する-1-度だけ))
> - **Windows 11 では、管理者ではない PowerShell で実行する** (手順 6 で VC++ ランタイムを入れるときだけ、インストーラーの UAC を許可する。標準ユーザーなら管理者の認証が必要)
> - **対話入力がある**: AlmaLinux 導入の手順 3 (`[y/N]` と EPEL の鍵)、手順 8 (Homebrew の `RETURN` と `sudo` のパスワード)、手順 10 (`brew` の `[y/n]`)、Windows 導入の手順 6 (VC++ ランタイムが無いときの UAC)、[GitLab プレビューのトークンの節](#gitlab-プレビューのトークンを設定する-任意)の手順 1〜4 (トークンと GitLab の URL)。答えてから次の手順を貼る
> - **Neovim の画面が開く**: AlmaLinux 導入の手順 17・19、Windows 導入の手順 9・11、[SSH の節](#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 2。`:qa` で閉じてから次の手順を貼る
> - **AlmaLinux 導入の手順 15 の後で、ログアウトしてログインし直す** (入れた ibus-anthy と入力ソースを読み直させる)。[上部バーの節](#gnome-の上部バーを-ime-連携に合わせる-任意)の手順 2 でも、拡張を読ませるためにログインし直す

| シナリオ | 頻度 | 内容 |
|---|---|---|
| [AlmaLinux 10 に導入する](#almalinux-10-に導入する-1-度だけ) | マシンごとに 1 度 | 外部コマンド・Neovim・日本語入力・フォントを入れ、この設定を clone して初回起動する |
| [Windows 11 に導入する](#windows-11-に導入する-1-度だけ) | マシンごとに 1 度 | scoop で外部コマンド・Neovim・zenhan を入れ、この設定を clone して初回起動する |
| [ほかのマシンの変更を取り込む](#ほかのマシンの変更を取り込む-繰り返し) | 繰り返し | 別のマシンで push した設定と `lazy-lock.json` を取り込み、プラグインの版を揃える |
| [GitLab Markdown の安全な整形を導入する](#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後) | 初回と整形用依存の変更後 | 説明リストを検査する整形用の npm 依存を入れ、保存と手動整形を確かめる |
| [GitLab Markdown 整形器の回帰テストを実行する](#gitlab-markdown-整形器の回帰テストを実行する-開発時) | 開発時 | 説明リストの保持、整形用設定、Neovim の配線を確認する |
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
- この設定で何ができるかは [README](../README.md)。外部コマンドの用途は[必要なもの一覧](#必要なもの一覧)


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


1. 外部コマンドと日本語入力 (ibus-anthy) を dnf で入れる。

   ```bash
   sudo dnf install git ripgrep fd-find gcc curl tar gzip unzip nodejs nodejs-npm file procps-ng ibus-anthy wl-clipboard
   ```

   - 何に使うかは[必要なもの一覧](#必要なもの一覧)
   - EPEL の署名鍵をまだ取り込んでいなければ、ここで 1 回だけ確認を求められる
   - 鍵の fingerprint が `7D8D 15CB FC4E 6268 8591 FB26 33D9 8517 E37E D158` (`Fedora (epel10)`) であることを確かめてから `y` と答える
   - **次の手順は、トランザクション表の `[y/N]` と鍵の確認に答えてから貼る** (続けて貼ると答えとして食われる)


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


1. この設定を `~/.config/nvim` に clone する。

   ```bash
   [ -e ~/.config/nvim/init.lua ] || git clone https://github.com/ryo-aoki-pc/LazyVimStarter.git ~/.config/nvim
   git -C ~/.config/nvim branch --show-current
   ```

   - `custom` と出ればよい (実運用の設定のブランチで、このリポジトリの既定のブランチ)
   - すでに clone してあれば、`git clone` は飛ばされる


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


1. `~/.bashrc` に 1 行書き、`brew` を PATH に入れる。

   ```bash
   grep -qF 'brew shellenv' ~/.bashrc || echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> ~/.bashrc
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
   brew --version
   ```

   - `Homebrew 7.…` と版が出ればよい
   - すでに `brew shellenv` の行があれば、`~/.bashrc` には足さない
   - ほかの端末は、開き直すと `brew` が使える
   - 自分用の bash の設定 (`ryo-aoki-pc/bash`) を入れたホストでは、このブロックは貼らない。代わりに `. ~/.bashrc` と `brew --version` を実行する (その設定が同じ 1 行を読む)

1. Neovim と lazygit を Homebrew で入れる。

   ```bash
   brew install neovim lazygit
   ```

   - 入るものの一覧 (依存 7 つを含む) の後に `Do you want to proceed with the installation? [y/n]` と聞かれる。`y` と答える
   - lazygit は任意 (無ければ `<leader>gg` が定義されないだけ)
   - **次の手順は、`[y/n]` に答えてインストールが終わってから貼る** (続けて貼ると答えとして食われる)


1. Neovim と lazygit が入ったか確かめる。

   ```bash
   nvim --version | head -1
   command -v nvim lazygit
   ```

   - `NVIM v0.12.…` と出ればよい (0.12 以上が要る)
   - 2 つとも `/home/linuxbrew/.linuxbrew/bin/…` と出る


1. フォント HackGen Console NF を Homebrew の cask で入れる。

   ```bash
   brew install --cask font-hackgen-nerd
   fc-match 'HackGen Console NF'
   ```

   - `HackGenConsoleNF-Regular.ttf: "HackGen Console NF" "Regular"` と出ればよい
   - フォントは `~/.local/share/fonts` に入る
   - 端末 (GNOME Terminal / WezTerm など) のフォントを HackGen Console NF にする。しないと、アイコンが豆腐 (□) になる
   - WezTerm では `treat_east_asian_ambiguous_width_as_wide` を既定 (false) のままにする


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
   - **注意**: JIS 配列のキーボードでも `us` にする。IME 連携が英数を `xkb:us::eng` に固定しているため
   - `gsettings` は `/usr/bin/gsettings` と場所まで書く。Homebrew の `gsettings` は GNOME の設定 (dconf) に書かない


1. Anthy の `on_off` のキーから `Ctrl+J` と `Ctrl+space` を外した値を作る。

   ```bash
   ANTHY_SHORTCUT=$(/usr/bin/gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | sed "s/'on_off': <\['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J'\]>/'on_off': <['Zenkaku_Hankaku']>/")
   printf '%s\n' "${ANTHY_SHORTCUT}" | grep -o "'on_off': <\[[^]]*\]>"
   ```

   - `'on_off': <['Zenkaku_Hankaku']>` と出ればよい
   - `Ctrl+J` が残っている・何も出ないときは、この節の手順 15 は飛ばす。代わりに `ibus-setup-anthy` の「キー割り当て」で `on_off` から `Ctrl+J` と `Ctrl+space` を消す
   - **次の手順は、出た行を目で確かめてから貼る**


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


1. 外部コマンドと Mason のツールが揃ったかを、`checkhealth` で確かめる。

   ```bash
   ls ~/.local/share/nvim/mason/bin
   nvim --headless "+Lazy! load mason.nvim luamigemo" "+checkhealth lazyvim luamigemo" "+w! /tmp/lazyvim-health.txt" +qa
   grep -E 'ERROR|WARNING' /tmp/lazyvim-health.txt
   ```

   - `mason/bin` に `markdownlint-cli2` / `marksman` / `stylua` / `tree-sitter` などが並ぶ
   - `grep` が何も出さないか、`` WARNING `fzf` is not installed `` の 1 行だけならよい (無視してよい。fzf が入っていれば出ない)
   - `ERROR` が出たら[注意点](#注意点)


1. 試験用の Markdown を開き、日本語検索・整形・IME 連携を確かめる。

   ```bash
   nvim /tmp/lazyvim-check.md
   ```

   - `/kensaku` と打って Enter を押す。3 行目の「検索」にカーソルが移り、`[1/1]` と出る
   - `/kensaku` と打って `<Tab>` を押す。入力が「検索」に置き換わる (候補が 1 つなので、すぐ確定する)。`<Esc>` で抜ける
   - 初めてなら [安全な整形の導入](#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後) を済ませる
   - `:w` で保存する。1 行目が `# 動作確認` に直る (glfm_markdownlint の整形)
   - 遅い VM では整形に数秒掛かる。Markdown / MDX の待ち時間の上限は 10 秒で、処理が終わればすぐ戻る
   - `o` で行を開き、`<C-j>` を押す。下の表示が `A` から `あ` に変わる。`<Esc>` で `A` に戻る
   - `<C-j>` を押したときは、カーソルのすぐ下にも `あ` / `A` が約 1 秒出る
   - `/` を押す。最下段の検索欄の右端に `A` が出る。`<C-j>` で `あ` に変わり、検索欄のカーソルのすぐ上にも `あ` が約 1 秒出て、カーソルが橙になる
   - `<Esc>` で抜ける。下の表示が `A` に戻り、次の `/` は `あ` で始まる (検索の sticky)。`<C-j>` で `A` にしてから `<Esc>` で抜ける
   - Space を 2 回押してファイルピッカーを開き、アイコンが豆腐でないことを見る (`<Esc>` で閉じる)
   - `:qa!` で閉じる (`o` で足した行は保存しない)
   - これで導入は終わり


### Windows 11 に導入する (1 度だけ)

- Windows 11 に scoop で外部コマンド・Neovim・zenhan を入れ、この設定を `%LOCALAPPDATA%\nvim` に clone して初回起動する
- 管理者ではない PowerShell で貼る。Windows PowerShell 5.1 でも PowerShell 7 でもよい

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

1. Visual C++ のランタイムが無いときだけ入れ、外部コマンド・Neovim・zenhan・lazygit を scoop で入れる。

   ```powershell
   if (-not (Test-Path -LiteralPath "$env:WINDIR\System32\vcruntime140.dll")) { scoop install vcredist2022 }
   scoop install neovim ripgrep fd gcc nodejs zenhan lazygit
   ```

   - 1 行目は、ランタイム (`System32\vcruntime140.dll`) がすでにあれば何もしない (ほかのアプリや winget で入れてある PC では、UAC も出ない)
   - ランタイムが無ければ `vcredist2022` を入れる。PowerShell は非管理者のまま、Visual C++ のインストーラーの UAC を許可する (x64・x86 の両方を入れる。標準ユーザーなら管理者の認証情報が要る)
   - `zenhan` は IME 連携に使う。無ければ IME 連携だけが静かに無効になる
   - `lazygit` は任意 (無ければ `<leader>gg` が定義されないだけ)
   - 2 行目のパッケージは、導入済みなら何も出さずに飛ばされる (scoop は複数を並べると `already installed` を出さない)


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
   - 理由は [lock 復元の説明](reference/setup.md#lazy-lockjson-を戻してから-restore-する理由)を参照する
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
   - 初めてなら [安全な整形の導入](#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後) を済ませる
   - `:lua =vim.fn.executable("zenhan")` が `1` なら IME 連携が有効 (`0` でもほかは動く)
   - OS 側で IME を切り替えても、Neovim は気付けない (lualine の `あ` / `A` がずれることがある。[機能と設定](reference/configuration.md#日本語入力検索))
   - `:qa!` で閉じる。これで導入は終わり

### ほかのマシンの変更を取り込む (繰り返し)

- 別のマシンで push した設定の変更と `lazy-lock.json` を取り込み、プラグインをその版に揃える
- AlmaLinux 10 はこの節の手順 1、Windows 11 はこの節の手順 2 を貼る
- Mason のツールや treesitter のパーサーが増えたときは、次に Neovim でファイルを開いたときに入る
- 初回と `tools/glfm-format/package-lock.json` が変わったときは、取り込み後に [安全な整形の導入](#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後) を行う
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

### GitLab Markdown の安全な整形を導入する (初回と依存の変更後)

- AlmaLinux 10 / Windows 11 共通。Node.js 22 以上と npm が必要
- 初回と `tools/glfm-format/package-lock.json` の変更後に行う
- 整形用依存は Neovim のデータディレクトリの `glfm-format` に入る。Mason のツールとは別に管理する

1. Neovim で整形用の依存を導入する。

   ```vim
   :GlfmFormatInstall
   ```

   - 完了の通知が出るまで待つ
   - 取得するのは lock ファイルで固定した markdownlint-cli2 と Comrak (WASM 版)。整形時は通信しない
   - 失敗したら Node.js と npm が PATH にあるか確かめ、同じコマンドを入力し直す
   - lint の診断用は `:MasonInstall markdownlint-cli2` で導入する

1. Markdown ファイルで保存と手動整形を確かめる。

   ```markdown
   #動作確認

   用語
   : 説明

     - 内部の項目
   ```

   - `:w` または `<leader>cf` で `#動作確認` が `# 動作確認` に直る
   - `内部の項目` の行頭の 2 スペースが保たれる
   - `<leader>cf` はビジュアル選択した範囲にも使える
   - 説明の対応や本文を変える修正は除外するため、一部の lint 診断は残ることがある
   - `:ConformInfo` に `glfm_markdownlint` が出る。依存不足・設定不正・時間切れのときは原文を保持し、エラーを知らせる

### GitLab Markdown 整形器の回帰テストを実行する (開発時)

- 整形器を開発するときに行う。[安全な整形の導入](#gitlab-markdown-の安全な整形を導入する-初回と依存の変更後)を先に済ませる
- Node.js 22 以上と、インストール済みの conform.nvim が必要

1. AlmaLinux 10 では、説明リスト・GLFM 記法・設定の引き継ぎと Neovim の配線を確かめる。

   ```bash
   GLFM_FORMAT_RUNTIME_DIR="$HOME/.local/share/nvim/glfm-format" node --test ~/.config/nvim/tools/glfm-format/test/*.test.mjs
   nvim --headless -u NONE -i NONE -l ~/.config/nvim/tools/glfm-format/test/conform.lua
   ```

   - Node のテストがすべて通り、Neovim が `GLFM conform / installer integration: PASS` を出せばよい
   - Neovim の確認では lazy.nvim の導入・更新を起動しない

1. Windows 11 では、(この節の手順 1 の代わりに) 同じ回帰テストを実行する。

   ```powershell
   $env:GLFM_FORMAT_RUNTIME_DIR = "$env:LOCALAPPDATA\nvim-data\glfm-format"
   node --test "$env:LOCALAPPDATA\nvim\tools\glfm-format\test\format.test.mjs"
   nvim --headless -u NONE -i NONE -l "$env:LOCALAPPDATA\nvim\tools\glfm-format\test\conform.lua"
   ```

   - 期待する結果はこの節の手順 1 と同じ

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
- 編集中の内容とトークンは、ここで設定する GitLab (空なら gitlab.com) にだけ送られる ([機能と設定](reference/configuration.md#markdown--glfm-執筆))
- AlmaLinux 10 はこの節の手順 1・2・5、Windows 11 はこの節の手順 3・4・6 を貼る。消すときは手順 7 (AlmaLinux 10) / 手順 8 (Windows 11)

1. AlmaLinux 10 では、トークンを入力して `~/.bashrc` に書く。

   ```bash
   read -rsp 'GitLab のトークン: ' t && echo && sed -i '/^export GITLAB_TOKEN=/d' ~/.bashrc && printf 'export GITLAB_TOKEN=%q\n' "$t" >> ~/.bashrc; unset t
   ```

   - `GitLab のトークン: ` と出るので、トークンを貼って Enter を押す (画面には出ない)
   - 前に書いた `GITLAB_TOKEN` の行があれば、書き直す
   - **次の手順は、トークンを入力してから貼る**


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


---

## 更新

- Neovim・外部コマンド・プラグインを上げる。設定そのものの取り込みは[ほかのマシンの変更を取り込む](#ほかのマシンの変更を取り込む-繰り返し)
- AlmaLinux 10 はこの節の手順 1・3、Windows 11 はこの節の手順 2・4 を貼る
- プラグインを上げると `lazy-lock.json` が変わる。確かめてからコミットし、push する ([機能と設定の lazy-lock.json の運用](reference/configuration.md#lazy-lockjson-の運用))

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
- Windows 11 の手順 5〜7 は、設定の置き場所と scoop を一時的な場所に差し替えた環境で通した

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
   - `brew autoremove` は、それでも残った不要な依存を消す
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


## 前提・確認・対処

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
| [Neovim](https://neovim.io/) 0.12 以上 | 本体。LazyVim の下限は 0.11.2 だが、`lazy-lock.json` の nvim-treesitter が 0.12 を要る | 必須  |
| git | lazy.nvim の bootstrap、プラグインの取得・更新、git 系ピッカー | 必須 |
| PowerShell (pwsh 推奨) | Windows の `shell`。外部コマンドと端末が全部これを通る | Windows で必須 |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | grep ピッカーと `grepprg`、`/` の `<Tab>` で出す Migemo の候補 | 必須 |
| [fd](https://github.com/sharkdp/fd) | ファイルピッカーと explorer | Windows で必須 / Linux では推奨 |
| C コンパイラ (gcc または MSVC の cl) | treesitter のパーサーのビルド | 必須 |
| tree-sitter CLI | treesitter のパーサーのビルド。PATH に無ければ LazyVim が Mason で入れる | 必須 (自動で入る) |
| curl / tar / gzip / unzip | treesitter と Mason の取得・展開。curl は GitLab プレビューが GitLab の API を呼ぶのにも使う (8.3 以上) | 必須 (Windows 11 は同梱の curl と tar だけでよい。[Windows の外部コマンドの説明](reference/setup.md#windows-の外部コマンド)) |
| [Node.js](https://nodejs.org/) 22 以上 (node + npm) | Mason の LSP・lint と、安全な Markdown 整形用依存 | 必須 |
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

### 完了時点の状態

| 場所 | 中身 |
|---|---|
| `~/.config/nvim` (`%LOCALAPPDATA%\nvim`) | このリポジトリの clone (`custom` ブランチ) |
| `~/.local/share/nvim/lazy` | プラグイン 38 個 (`lazy-lock.json` の版) |
| `~/.local/share/nvim/mason` | Mason のツール 11 個 |
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

- **Windows で `nvim` が起動しない (`VCRUNTIME140.dll が見つからない` / `0xC0000135`)**: Visual C++ のランタイムが入っていない
  - scoop の `neovim` は `VCRUNTIME140.dll` を同梱しない (`nvim.exe` と `lua51.dll` が読み込む)。[Windows 導入の手順 6](#windows-11-に導入する-1-度だけ)の 1 行目が、`System32\vcruntime140.dll` が無いときだけ `vcredist2022` を入れる。手順 7 の `nvim --version` で確かめる
  - `vcruntime140.dll` があるのに手順 7 の `nvim --version` が通らないときは、`scoop install vcredist2022` を条件を付けずに貼り、今の版のランタイムを入れる (手順 6 の 1 行目はファイルの有無だけを見て、版は見ない)。`already installed` と出たら、`scoop uninstall vcredist2022` の後にもう一度貼る (uninstall で消えるのはインストーラーだけで、ランタイムは残る)
  - VC++ のランタイムが無いクリーンインストールの Windows 11 VM では、Neovim 0.12.5 が終了コード `-1073741515` (`0xC0000135`) になり、起動しなかった
- **一部の Mason のツールだけが入らない (`stylua` など)**: `unzip` が無い
  - Mason は zip で配布されるツールの展開に `unzip` を使い、無いと**そのツールだけ**が静かに失敗する
  - `:Mason` で状態を見て、`sudo dnf install unzip` の後に入れ直す
- **npm で入るツールだけが入らない (`markdownlint-cli2` など)**: node と npm が無いか、npm が registry に届かない
  - `~/.local/state/nvim/mason.log` に npm のエラーが残る。
- **treesitter のハイライトが効かない**: C コンパイラか tree-sitter CLI が見つかっていない
  - `:checkhealth lazyvim` の `LazyVim nvim-treesitter` の節で `C compiler` と `tree-sitter (CLI)` を見る
  - Windows で `gcc` を入れた直後は PATH が反映されていないことがある。端末を開き直してから `nvim` を起動する
- **ファイルピッカーが空のまま**: `fd` も `rg` も無い。Linux には `find` へのフォールバックがあるが、Windows には無い
- **保存しても Markdown が整形されない / lint が出ない**: Node.js 22 以上と npm が必要
  - 整形用の依存は `:GlfmFormatInstall` で導入する。設定を取り込んで lock ファイルが変わったときも入力する
  - lint の診断用は `:Mason` で状態を見て、`:MasonInstall markdownlint-cli2` で入れ直す
  - `:ConformInfo` を開く。`Formatter 'glfm_markdownlint' timeout` は整形の時間切れで、ツールの未導入とは区別する
  - Markdown / MDX の整形上限は 10 秒。ほかのファイルは既定の 3 秒
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
  - 初めてのマシンの初回起動でも変わる ([lock 復元の説明](reference/setup.md#lazy-lockjson-を戻してから-restore-する理由))
- **日本語のときに `<C-j>` で英数に戻らない (Linux)**: Anthy の `on_off` に `Ctrl+J` が残っていて、Neovim に届く前に Anthy の中のひらがなと英字が切り替わっている
  - 打った英字が、そのまま出たり「あ」になったりと、日本語の中で入力が揺れるのが特徴
  - AlmaLinux 導入の手順 13〜15 を Homebrew の `gsettings` で実行すると、dconf ではなく `~/.config/glib-2.0/settings/keyfile` に書かれて効かない
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
