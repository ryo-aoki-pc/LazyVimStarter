# 事前準備 (新しいマシンでのセットアップ)

この設定を新しいマシンで動かすまでの手順。Neovim 本体のほかに外部コマンドをいくつか
前提にしており、足りないと「ファイルピッカーが空のまま」「保存しても Markdown が整形
されない」のように静かに壊れる。エラーが出ない種類の壊れ方なので、先に全部入れてから
初回起動するのが結局は早い。

対象は Windows 11 と Linux。設定そのものの説明は [../README.md](../README.md) を参照。

## 必要なもの一覧

| 依存 | 用途 | 必須? |
| --- | --- | --- |
| [Neovim](https://neovim.io/) 0.11.3 以上 | 本体 | 必須 (0.11.2 でも `:checkhealth` は緑のまま日本語検索だけ死ぬ。[つまずきやすい点](#つまずきやすい点)) |
| git | lazy.nvim の bootstrap、プラグインの取得・更新、git 系ピッカー | 必須 |
| PowerShell (pwsh 推奨) | Windows の `shell`。外部コマンドと端末が全部これを通る | Windows で必須 |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | grep ピッカーと `grepprg` | 必須 |
| [fd](https://github.com/sharkdp/fd) | ファイルピッカーと explorer | Windows で必須 / Linux では推奨 |
| C コンパイラ (gcc または MSVC の cl) | treesitter パーサーのビルド | 必須 |
| curl / tar / gzip / unzip | treesitter と Mason の取得・展開 | 必須 |
| [Node.js](https://nodejs.org/) (node + npm) | Mason が npm で入れる LSP・整形ツール、Markdown プレビュー | 必須 |
| [Deno](https://deno.com/) | denops (vim-kensaku の実行基盤) | 日本語検索に必須 |
| Nerd Font ([HackGen Console NF](https://github.com/yuru7/HackGen)) | アイコン表示と `guifont` | 実質必須 (無いと記号が豆腐になる) |
| ibus + ibus-anthy | 日本語入力 (Linux)。global engine を切り替える | Linux で必須 |
| [zenhan](https://github.com/iuchim/zenhan) または im-select | 日本語入力 (Windows) | 任意 (無ければ IME 連携のみ無効) |
| lazygit | `<leader>gg` | 任意 (無ければキーマップが定義されないだけ) |
| ネットワーク | 初回のプラグイン取得、Mason、treesitter パーサー、kensaku の辞書 | 初回のみ必須 |

`unzip` は Mason が zip 配布のツール (`stylua` など) を展開するのに使う。無いと
**そのツールだけ**が静かに入らず、他は入るので気付きにくい。Deno の公式インストーラも
展開に使う。

**不要なもの** — fzf (ピッカーは snacks.nvim の Lua 実装。`:checkhealth lazyvim` が
警告を出すが機能には影響しない)、telescope とその C ビルド (使っていない)、make、
Python、win32yank (Neovim の Windows ビルドに同梱済み)。

## Windows 11

パッケージマネージャは [scoop](https://scoop.sh/) を使う (管理者権限が要らず、
すべて `%USERPROFILE%\scoop` に収まるため)。winget や手動インストールでも構わないが、
その場合は **各コマンドが PATH に載っていること**だけ確認すること。この設定は
コマンドの場所を一切ハードコードせず、`executable()` で PATH を見て機能を出し入れする。

### 1) scoop

```powershell
# 既に scoop があれば飛ばしてよい。
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

### 2) Neovim と必須コマンド

```powershell
# 1) 本体と必須コマンド。すべて main バケットにある。
scoop install neovim ripgrep fd gcc nodejs deno

# 2) git。Git for Windows を入れている場合は不要 (重複するので入れない)。
#    ★ Git for Windows は curl / tar / gzip / unzip も一緒に入れてくれるので、
#      Windows 11 同梱の curl.exe / tar.exe と合わせて Mason の要求を満たせる。
scoop install git

# 3) 任意。lazygit だけ extras バケット。
scoop bucket add extras
scoop install lazygit
```

`curl` と `tar` は Windows 11 が `C:\Windows\System32` に同梱しているので追加不要。
`gzip` は同梱されないが、Git for Windows (`C:\Program Files\Git\usr\bin`) が持っている。
Mason はこの 3 つが無いとツールのダウンロードに失敗する。

### 3) C コンパイラ (nvim-treesitter 用)

nvim-treesitter は各言語のパーサーを **手元で C としてコンパイル**するため、
コンパイラが無いとハイライトが一切効かない。`gcc` か MSVC の `cl.exe` のどちらかでよい。

上の手順で `scoop install gcc` を済ませていれば PATH に `gcc` が載るので、それ以上の
設定は要らない (LazyVim が PATH の `gcc` を見つけて `$CC` に自動で設定する)。
scoop を使わない場合は LazyVim 自身が案内する WinLibs が手軽:

```powershell
winget install --id=BrechtSanders.WinLibs.POSIX.UCRT
```

Visual Studio Build Tools を既に入れているなら `cl.exe` も自動検出される
(LazyVim が `C:/Program Files (x86)/Microsoft Visual Studio/...` を探しにいく)。

### 4) Node.js と Deno

どちらも「入れなくても起動はするが、機能が黙って死ぬ」たぐいの依存なので、
何のために必要かを把握しておくとよい。

- **node + npm** — Mason が `markdownlint-cli2` / `markdown-toc` /
  `bash-language-server` / `json-lsp` / `yaml-language-server` を npm パッケージとして
  入れる。つまり **node を消すと Markdown の lint と整形が丸ごと止まる**。
  `markdown-preview.nvim` もプリビルド版を入れていない間は node で動く。
- **deno** — vim-kensaku (ローマ字のまま日本語をバッファ検索する) の実行基盤 denops が
  Deno を必須にしており、無いと起動時に「Denops requires executable Deno.」で止まる。
  この構成では IME を入れ直さずに日本語検索できることが要なので、実質必須。

### 5) IME 連携 (zenhan)

```powershell
scoop install zenhan   # main バケット
```

`zenhan.exe` が PATH にあれば、Neovim のモードに合わせて OS の IME が切り替わる。
`im-select.exe` でも動く (両方あれば zenhan が優先される)。どちらも無い場合は
IME 連携だけが静かに無効化され、エラーは出ない。Windows 側の制限については
[README の補足](../README.md#補足) を参照。

### 6) フォントと端末

`HackGen Console NF` を [yuru7/HackGen のリリース](https://github.com/yuru7/HackGen/releases)
から入手する。展開して `.ttf` を右クリック → 「インストール」。Nerd Font なら他のもので
もよいが、その場合は `lua/config/options.lua` の `guifont` も書き換えること。

`guifont` が効くのは neovide などの GUI クライアントだけで、端末 (WezTerm 等) では
**端末側のフォント設定が使われる**。端末で使うなら端末側にも同じフォントを指定すること。

WezTerm を使う場合は `treat_east_asian_ambiguous_width_as_wide` を既定 (false) のままに
しておく。Neovim 側の `ambiwidth` を既定 (single) のままにしてあり、片方だけ変えると
`○` `±` `①` などを含む行の桁が丸ごとずれる (理由は `lua/config/options.lua` のコメント)。

## Linux

ディストリごとにパッケージ名が違うので、Debian/Ubuntu 系・Fedora 系・RHEL 系を併記する。

### 1) Neovim と必須コマンド

```sh
# Debian / Ubuntu
sudo apt install git ripgrep fd-find build-essential curl tar gzip unzip

# Fedora
sudo dnf install git ripgrep fd-find gcc curl tar gzip unzip

# RHEL 系 (AlmaLinux / Rocky / RHEL)
# ★ ripgrep と fd-find は base リポジトリに無い。先に EPEL を足さないと
#   「Unable to find a match: ripgrep fd-find」で止まる。
sudo dnf install epel-release
sudo dnf install git ripgrep fd-find gcc curl tar gzip unzip
```

`fd-find` のコマンド名はディストリによって違う。**Debian/Ubuntu だけが `fdfind`** で、
Fedora / EPEL は `fd` のまま。この設定 (snacks.nvim) は両方を探すのでどちらでも動く。

#### Neovim 本体

★ **ディストリの Neovim はたいてい古すぎる** (Ubuntu 24.04 は 0.9 系、EPEL 10 は 0.10.1)。
この設定は 0.11.3 以上を要求するので、リポジトリ版を入れる前にバージョンを確認すること。
古い場合は **Homebrew が最も手軽** — Linux は x86_64 / aarch64 ともボトル (ビルド済み
バイナリ) が用意されており、ソースビルドを待たずに最新版が入る。

```sh
# Homebrew (未導入なら)。前提は上で入れた git / curl に加えて file / procps-ng。
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"   # ~/.bashrc にも追記しておく

brew install neovim

nvim --version | head -1   # v0.11.3 以上であること
```

★ Homebrew を入れると `python@3.x` が依存として link されることがあり、そうなると
**ibus-anthy が起動できなくなって OS 全体で日本語が打てなくなる**。症状と対処は
[README のトラブルシューティング](../README.md#トラブルシューティング--日本語が一切入力できない-linux)
にある。

Homebrew を使いたくない場合は [公式リリース](https://github.com/neovim/neovim/releases) の
tar.gz を展開して PATH に通す (`nvim-linux-x86_64.tar.gz` / `nvim-linux-arm64.tar.gz`)。
AppImage も配布されているが **FUSE を必要とする**ため、コンテナや FUSE の無い環境では
`fuse: device not found` で起動しない。その場合は `--appimage-extract` で展開して
`squashfs-root/AppRun` を使う。

### 2) Node.js と Deno

必要な理由は [Windows の節](#4-nodejs-と-deno) と同じ。

```sh
# Debian / Ubuntu (ディストリ版が古い場合は NodeSource や fnm を使う)
sudo apt install nodejs npm

# RHEL 系 (npm は nodejs-npm パッケージだが `npm` 指定でも解決される)
sudo dnf install nodejs npm

# Deno はディストリに無いことが多いので公式スクリプトで入れる (展開に unzip を使う)。
# ★ このスクリプトは ~/.deno/bin に置くだけで PATH を通さない (非対話実行時)。
#   自分で追記しないと nvim から deno が見えず、日本語検索が黙って動かない。
curl -fsSL https://deno.land/install.sh | sh
echo 'export PATH="$HOME/.deno/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.deno/bin:$PATH"

node --version   # v18 以上 (Mason の要求)
npm --version    # v7 以上
deno --version
```

Homebrew を入れてあるなら `brew install deno` でもよい (こちらは PATH が通った状態になる)。

### 3) 日本語入力 (ibus + anthy)

```sh
# Debian / Ubuntu
sudo apt install ibus ibus-anthy

# Fedora
sudo dnf install ibus-anthy
```

Neovim から ibus への通信には `busctl` (systemd 同梱) か `gdbus` (glib2 同梱) を使う。
どちらか 1 つあればよく、通常はどちらも既に入っている (`gdbus` があれば OS 側の
IME 切り替えも検知できるので、lualine の `あ` / `A` 表示がズレない)。

インストールした後、**GNOME の入力ソース登録と anthy のショートカット調整が必要**。
手順は [README のセットアップ節](../README.md#セットアップ-linux--gnome--ibus初回のみ)
にあるのでそちらを実施すること (この 2 つをやらないと `<C-j>` が anthy に食われる)。

### 4) フォント

`HackGen Console NF` を [リリース](https://github.com/yuru7/HackGen/releases) から
入手し、`~/.local/share/fonts/` に置いて `fc-cache -fv` を実行する。

```sh
fc-list | grep -i hackgen   # 認識されたか確認
```

## 設定の配置と初回起動

Neovim の設定ディレクトリそのものがこのリポジトリなので、clone 先を間違えないこと。

```powershell
# Windows
# 1) 既存の設定とデータを退避する (Neovim が初めてなら不要)。
Move-Item $env:LOCALAPPDATA\nvim      $env:LOCALAPPDATA\nvim.bak
Move-Item $env:LOCALAPPDATA\nvim-data $env:LOCALAPPDATA\nvim-data.bak

# 2) clone する。SSH 鍵を GitHub に登録していなければ HTTPS を使う
#    (このリポジトリは public なので鍵は要らない)。
git clone https://github.com/ryo-aoki-pc/LazyVimStarter.git $env:LOCALAPPDATA\nvim

# 3) 起動する。lazy.nvim の bootstrap → プラグイン取得 → treesitter のビルド →
#    Mason のツール導入が続けて走るので、落ち着くまで数分待つ。
nvim
```

```sh
# Linux
# 1) 既存の設定とデータを退避する (Neovim が初めてなら不要)。
mv ~/.config/nvim       ~/.config/nvim.bak
mv ~/.local/share/nvim  ~/.local/share/nvim.bak
mv ~/.local/state/nvim  ~/.local/state/nvim.bak
mv ~/.cache/nvim        ~/.cache/nvim.bak

# 2) clone する。SSH 鍵を GitHub に登録していない新しいマシンでは
#    git@github.com: 形式は "Host key verification failed" で失敗するので、
#    その場合は HTTPS を使う (このリポジトリは public なので鍵は要らない)。
git clone https://github.com/ryo-aoki-pc/LazyVimStarter.git ~/.config/nvim

# 3) 起動する。
nvim
```

初回のプラグイン導入が落ち着いたら、`lazy-lock.json` に記録されたバージョンへ揃える。

```vim
:Lazy restore
```

lazy.nvim は初回に各プラグインの最新コミットを取ってくるため、これをやらないと
別マシンと違うバージョンで動くことになる (運用方針は
[README の lazy-lock.json の運用](../README.md#lazy-lockjson-の運用) を参照)。

## 動作確認

```vim
:checkhealth lazyvim   " Neovim のバージョン、git/rg/fd/lazygit/curl、treesitter の C コンパイラ
:checkhealth mason     " curl / tar / gzip と node / npm
:Lazy                  " 全プラグインが installed になっているか
:Mason                 " markdownlint-cli2 / markdown-toc / marksman 等が入ったか
```

`:checkhealth lazyvim` の `fzf is not installed` 警告は無視してよい (この設定では
ピッカーに snacks.nvim を使っており fzf バイナリを呼ばない)。

機能ごとの確認:

```vim
:lua =vim.fn.executable("deno")    " 1 が返れば日本語検索が動く
:lua =vim.fn.executable("zenhan")  " Windows。1 なら IME 連携が有効 (0 でも他は動く)
```

スクリプトで確認したい場合は headless でも同じことができる (`!` を付けないと
`:Lazy sync` は待たずに戻り、`+qa` が取得途中のジョブを殺す点に注意)。

```sh
nvim --headless "+Lazy! sync" +qa      # 初回導入
nvim --headless "+Lazy! restore" +qa   # lazy-lock.json に揃える
nvim --headless "+Lazy! load mason.nvim nvim-treesitter" \
     "+checkhealth lazyvim" "+w! /tmp/health.txt" +qa && grep ERROR /tmp/health.txt
```

ただし headless には UI が無いため `UIEnter` が発火せず、それを待つ `VeryLazy` も
発火しない。**`lua/config/autocmds.lua` (IME 連携・CJK スペル・保存時整形の登録) は
読み込まれない**ので、これらの確認は通常どおり `nvim` を起動して行うこと。

- **日本語検索** — 日本語を含むファイルを開き、`/kensaku<CR>` で「検索」にマッチすれば成功。
  初回だけ辞書のダウンロードが走るので少し待つ。
- **IME 連携** — 挿入モードに入って `<C-j>` を押し、lualine の表示が `A` から `あ` に
  変われば成功。`<Esc>` で `A` に戻ること。
- **Markdown の整形** — `.md` を開いて保存し、markdownlint の指摘が自動修正されること。
- **アイコン** — ファイルピッカー (`<leader><space>`) のアイコンが豆腐でないこと。

## つまずきやすい点

**`:checkhealth` は緑なのに日本語検索だけ効かない** — Neovim が 0.11.2 以下。
LazyVim の health は 0.11.2 で `OK Using Neovim >= 0.11.2` を出すが、vim-kensaku の
実行基盤 denops は **0.11.3 以上**を要求しており、下回ると起動時に
`[denops] Denops requires Vim 9.1.1646 or Neovim 0.11.3.` を `:messages` に残して
黙って止まる。`:checkhealth` には一切出ないので、`nvim --version` を直接見ること。

**一部の Mason ツールだけが入らない (`stylua` など)** — `unzip` が無い。
Mason は zip で配布されるツールの展開に `unzip` を使い、無いと**そのツールだけ**
静かに失敗する (他のツールは入るので気付きにくい)。`:Mason` で状態を確認し、
`sudo dnf install unzip` (または `apt install unzip`) の後に入れ直す。

**treesitter のハイライトが一切効かない** — C コンパイラが見つかっていない。
`:checkhealth lazyvim` の `nvim-treesitter` 節で `C compiler` を確認する。
Windows で `gcc` を入れた直後は PATH が反映されていないことがあるので、
端末を開き直してから `nvim` を起動する。

**ファイルピッカーが空のまま** — `fd` も `rg` も無い。Linux には `find` への
フォールバックがあるが **Windows では無効**なので、どちらかを必ず入れること。

**保存しても Markdown が整形されない / lint が出ない** — `markdownlint-cli2` と
`markdown-toc` は npm パッケージなので、node を入れ替えたり消したりすると Mason の
導入済みツールごと壊れる。`:Mason` で状態を見て、
`:MasonInstall markdownlint-cli2 markdown-toc` で入れ直す。

**`/` からの日本語検索が効かない** — `deno` が PATH に無いか、初回の辞書ダウンロードが
ネットワークで失敗している。`:messages` に denops のエラーが残っていないか見る。
辞書のキャッシュ先は `stdpath("cache")/kensaku/` なので、壊れた場合は消せば再取得される。

**アイコンが豆腐 (□) になる** — 端末側のフォントが Nerd Font になっていない。
`guifont` は GUI クライアント専用で、端末には効かない。

**全角記号を含む行の桁がずれる** — Neovim の `ambiwidth` と端末の East Asian
Ambiguous 幅の設定が食い違っている。この設定は両方 narrow 側 (`single` /
`treat_east_asian_ambiguous_width_as_wide=false`) で揃えてあるので、端末側だけを
wide に変えないこと。

**日本語が一切入力できない (Linux)** — ibus のエンジン自体が起動に失敗している
可能性がある。切り分け手順は
[README のトラブルシューティング](../README.md#トラブルシューティング--日本語が一切入力できない-linux)
にある。
