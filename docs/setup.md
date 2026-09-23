# Neovim 設定のセットアップ手順 (Windows 11 / AlmaLinux 10)

## 実施手順

新しいマシンでこの設定を動かすまでの手順。コードブロックは OS ごとに分かれているので、
自分の OS のものだけを上から順に貼る。理由・実測・落とし穴は[補足](#補足)にまとめてあり、
実行するだけなら読まなくてよい。

**先に外部コマンドを全部入れてから初回起動する。** この設定はコマンドの有無を
`executable()` で見て機能を出し入れするため、足りないとエラーではなく「ファイルピッカーが
空のまま」「保存しても Markdown が整形されない」という静かな壊れ方をする。

| 手順 | 内容 |
|---|---|
| [0. 変数を設定する](#0-変数を設定する) | clone 先とリポジトリ URL を確認する (編集不要) |
| [1. パッケージマネージャを用意する](#1-パッケージマネージャを用意する) | Windows: scoop / Linux: EPEL と Homebrew |
| [2. 必須コマンドを入れる](#2-必須コマンドを入れる) | git・rg・fd・C コンパイラ・展開ツール・node |
| [3. Neovim 本体を入れる](#3-neovim-本体を入れる) | 0.11.2 以上であることまで確認する |
| [4. 日本語入力 (IME) を用意する](#4-日本語入力-ime-を用意する) | Linux: ibus + anthy と GNOME 側の設定 / Windows: zenhan |
| [5. フォントを入れる](#5-フォントを入れる) | HackGen Console NF |
| [6. 設定を配置して初回起動する](#6-設定を配置して初回起動する) | 退避 → clone → `nvim` → `:Lazy restore` |
| [7. 動作確認する](#7-動作確認する) | `:checkhealth` と機能ごとの確認 |

tmux でカーソル色を使うなら[カーソル色を tmux で効かせる (任意)](#カーソル色を-tmux-で効かせる-任意)。
元に戻すときは[ロールバック](#ロールバック)。

### 0. 変数を設定する

**このブロックは編集必須の変数が無い。** clone 先を既定から変えたいときだけ書き換える。
**新しいシェルを開いたら (SSH や PowerShell を開き直したあとも) 先にこのブロックを貼り直す。**

```powershell
# Windows
$NVIM_CONFIG = "$env:LOCALAPPDATA\nvim"                                  # 設定の置き場所 (既定)
$REPO_URL    = "https://github.com/ryo-aoki-pc/LazyVimStarter.git"       # このリポジトリ
```

```bash
# Linux
NVIM_CONFIG=~/.config/nvim                                          # 設定の置き場所 (既定)
REPO_URL=https://github.com/ryo-aoki-pc/LazyVimStarter.git          # このリポジトリ
```

**値を読み戻して確かめる。**

```powershell
# Windows
"NVIM_CONFIG = $NVIM_CONFIG"
"REPO_URL    = $REPO_URL"
```

```bash
# Linux
printf 'NVIM_CONFIG = %s\nREPO_URL    = %s\n' "${NVIM_CONFIG}" "${REPO_URL}"
```

→ [補足](#手順-0-変数について)

### 1. パッケージマネージャを用意する

Windows は [scoop](https://scoop.sh/)。既に入っていれば飛ばしてよい。

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

Linux は dnf に EPEL を足し、Neovim 用に Homebrew を入れる。`file` と `procps-ng` は
Homebrew の前提。**Homebrew のインストーラは root で実行しない。**

```bash
sudo dnf install epel-release
sudo dnf install file procps-ng curl git

# 未導入なら
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> ~/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
brew --version
```

→ [補足](#手順-1-パッケージマネージャの選択)

### 2. 必須コマンドを入れる

Windows。`git` は Git for Windows を入れているなら重複するので飛ばす。`lazygit` は任意。

```powershell
scoop install neovim ripgrep fd gcc nodejs
scoop install git

scoop bucket add extras
scoop install lazygit
```

`curl` と `tar` は Windows 11 に同梱、`gzip` と `unzip` は Git for Windows が持っている。

Linux。

```bash
sudo dnf install git ripgrep fd-find gcc curl tar gzip unzip
sudo dnf install nodejs npm
```

入ったことを確認する (Windows も同じコマンドでよい)。

```bash
node --version   # v18 以上
npm --version    # v7 以上
```

→ [補足](#手順-2-必須コマンドについて)

### 3. Neovim 本体を入れる

Windows は[手順 2](#2-必須コマンドを入れる) の `scoop install` で入っている。Linux は Homebrew で入れる
(ディストリの Neovim は古すぎる)。

```bash
brew install neovim
```

**0.11.2 以上であることを確認する** (LazyVim の要求)。

```bash
nvim --version   # 先頭行が NVIM v0.11.2 以上であること
```

→ [補足](#手順-3-neovim-の入手経路)

### 4. 日本語入力 (IME) を用意する

Windows は `zenhan.exe` があればモード連動が有効になる (無ければ IME 連携だけ静かに無効)。

```powershell
scoop install zenhan
```

Linux は ibus と anthy を入れる。

```bash
sudo dnf install ibus ibus-anthy
```

続けて **GNOME 側の設定を 2 つ**行う。これをやらないと `<C-j>` が anthy に食われて Neovim に
届かない。**tmux の中では `DBUS_SESSION_BUS_ADDRESS` が未設定で `gsettings` が既定値しか
読めず、書き込みも黙って効かない**ため、先に明示する。

```sh
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
```

1 つめ。入力ソースに「英語 (US)」を追加する (先頭に置くとログイン直後が英数で始まる)。

```sh
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'anthy')]"
gsettings get org.gnome.desktop.input-sources sources   # 反映確認
```

2 つめ。anthy の `on_off` ショートカットから `Ctrl+J` / `Ctrl+space` を外す。
**anthy の設定は schema 既定とマージされない。** 部分的な dict を書くと他のショートカットが
全部消えるので、**必ず全体を読んで置換し、目視で確認してから書き戻す。**

```sh
S=org.freedesktop.ibus.engine.anthy.shortcut
v=$(gsettings get $S default \
     | sed "s/'on_off': <\['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J'\]>/'on_off': <['Zenkaku_Hankaku']>/")
printf '%s\n' "$v" | grep -o "'on_off': <\[[^]]*\]>"   # 置換できたか目視してから
gsettings set $S default "$v"
```

置換に失敗する場合は `ibus-setup-anthy` の「キー割り当て」から `on_off` を編集する。
以後の日本語 ON/OFF は **Super+Space** と **Neovim の `<C-j>`** になる。

→ [補足](#手順-4-ime-連携の前提)

### 5. フォントを入れる

`HackGen Console NF` を [yuru7/HackGen のリリース](https://github.com/yuru7/HackGen/releases) から入手する。

- **Windows** — 展開して `.ttf` を右クリック →「インストール」。
- **Linux** — `~/.local/share/fonts/` に置いて `fc-cache -fv`。`fc-list | grep -i hackgen` で確認する。

**端末で使うなら端末側にも同じフォントを指定する** (`guifont` が効くのは neovide などの
GUI クライアントだけ)。別の Nerd Font を使うなら `lua/config/options.lua` の `guifont` も書き換える。

→ [補足](#手順-5-フォントと端末)

### 6. 設定を配置して初回起動する

**Neovim の設定ディレクトリそのものがこのリポジトリ**なので、clone 先を間違えないこと。
既存の設定とデータを退避してから clone する (Neovim が初めてなら退避は不要)。

```powershell
# Windows
Move-Item $env:LOCALAPPDATA\nvim      $env:LOCALAPPDATA\nvim.bak
Move-Item $env:LOCALAPPDATA\nvim-data $env:LOCALAPPDATA\nvim-data.bak

if (-not $REPO_URL -or -not $NVIM_CONFIG) { throw "手順 0 のブロックを貼り直す" }
git clone $REPO_URL $NVIM_CONFIG
nvim
```

```bash
# Linux
mv ~/.config/nvim       ~/.config/nvim.bak
mv ~/.local/share/nvim  ~/.local/share/nvim.bak
mv ~/.local/state/nvim  ~/.local/state/nvim.bak
mv ~/.cache/nvim        ~/.cache/nvim.bak

git clone "${REPO_URL:?手順 0 の REPO_URL が空のまま。値を入れて貼り直す}" \
          "${NVIM_CONFIG:?手順 0 の NVIM_CONFIG が空のまま。値を入れて貼り直す}"
nvim
```

初回起動では lazy.nvim の bootstrap → プラグイン取得 → treesitter のビルド → Mason の
ツール導入が続けて走る。落ち着くまで数分待つ。

落ち着いたら `lazy-lock.json` に記録されたバージョンへ揃える。

```vim
:Lazy restore
```

→ [補足](#手順-6-clone-先と-lazy-restore)

### 7. 動作確認する

```vim
:checkhealth lazyvim   " Neovim のバージョン、git/rg/fd/lazygit/curl、treesitter の C コンパイラ
:checkhealth mason     " curl / tar / gzip と node / npm
:Lazy                  " 全プラグインが installed になっているか
:Mason                 " markdownlint-cli2 / markdown-toc / marksman 等が入ったか
```

`:checkhealth lazyvim` の `fzf is not installed` 警告は無視してよい。

機能ごとの確認:

- **日本語検索** — 日本語を含むファイルを開き、`/kensaku<CR>` で「検索」にマッチすれば成功
  (辞書は同梱なのでネットワーク不要)。`s` → `nihongo` で「日本語」にラベルが付くことも見る。
- **IME 連携** — 挿入モードで `<C-j>` を押し、lualine の表示が `A` から `あ` に変われば成功。
  `<Esc>` で `A` に戻ること。
- **Markdown の整形** — `.md` を開いて保存し、markdownlint の指摘が自動修正されること。
- **アイコン** — ファイルピッカー (`<leader><space>`) のアイコンが豆腐でないこと。

コマンドで確認したい場合:

```vim
:checkhealth luamigemo             " 辞書と LuaJIT が OK なら日本語検索が動く
:lua =vim.fn.executable("zenhan")  " Windows。1 なら IME 連携が有効 (0 でも他は動く)
```

→ [補足](#手順-7-headless-での確認)

---

## カーソル色を tmux で効かせる (任意)

挿入モードのカーソル色も IME 状態で変わるが、`tmux-256color` には `Cs` / `Cr` が無く
Neovim が OSC 12 を出さないため、tmux 越しでは既定で効かない。使いたい場合は
`~/.config/tmux/tmux.conf` に足す (無くても無害)。

```tmux
set -ga terminal-overrides ',*:Cs=\E]12;%p1%s\007:Cr=\E]112\007'
```

---

## ロールバック

[手順 6](#6-設定を配置して初回起動する) で退避したものを戻す。

```powershell
# Windows
Remove-Item -Recurse -Force $env:LOCALAPPDATA\nvim, $env:LOCALAPPDATA\nvim-data
Move-Item $env:LOCALAPPDATA\nvim.bak      $env:LOCALAPPDATA\nvim
Move-Item $env:LOCALAPPDATA\nvim-data.bak $env:LOCALAPPDATA\nvim-data
```

```bash
# Linux
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
mv ~/.config/nvim.bak      ~/.config/nvim
mv ~/.local/share/nvim.bak ~/.local/share/nvim
mv ~/.local/state/nvim.bak ~/.local/state/nvim
mv ~/.cache/nvim.bak       ~/.cache/nvim
```

手順 1〜5 で入れたコマンドは他でも使うので、消すかどうかは別に判断する
(`scoop uninstall <名前>` / `brew uninstall neovim` / `sudo dnf remove <名前>`)。

本書ではロールバックは**本実行していない**。

---

## 補足

手順の理由・実測・落とし穴。実行するだけなら読まなくてよい。

### 対象と検証環境

- **目的**: 新しいマシンでこの Neovim 設定 (日本語編集 + Markdown 執筆向け) を動かす。
  設定そのものの説明は [../README.md](../README.md) を参照
- **進め方**: 外部コマンドを先に揃えてから初回起動する。**読者が書き換える値は実質無い**
- **状態**:
  - **Linux (AlmaLinux 10)** — AlmaLinux 10 の使い捨てコンテナで手順を頭から流して検証済み。
    実測で確認できた食い違い (Neovim の下限、`unzip` の要否、EPEL の要否) は本文に反映済み
  - **Windows 11** — **実機で常用中。ただし本文の手順を通しで実行してはいない。**
    依存の一覧はこの設定のコードを読んで確定させたもの
  - **ロールバック** — 本実行していない

| 項目 | Windows | Linux |
|---|---|---|
| OS | Windows 11 | AlmaLinux 10 |
| パッケージマネージャ | scoop | dnf + EPEL、Neovim のみ Homebrew |
| Neovim | scoop の `neovim` | Homebrew の `neovim` (0.11.2 以上) |
| IME | zenhan (任意) | ibus + ibus-anthy |

> **注記**: 環境固有の値は**シェル変数**で書いてある。[手順 0](#0-変数を設定する) で 1 度だけ
> 設定すれば、以降のコマンドはそのまま貼って実行できる。
>
> | 変数 | 意味 | 既定値 |
> |---|---|---|
> | `${NVIM_CONFIG}` | 設定の置き場所 = clone 先 | `~/.config/nvim` / `%LOCALAPPDATA%\nvim` |
> | `${REPO_URL}` | このリポジトリの URL | `https://github.com/ryo-aoki-pc/LazyVimStarter.git` |

### 必要なもの一覧

| 依存 | 用途 | 必須? |
| --- | --- | --- |
| [Neovim](https://neovim.io/) 0.11.2 以上 | 本体 (LazyVim の要求) | 必須 ([手順 3 の補足](#手順-3-neovim-の入手経路)) |
| git | lazy.nvim の bootstrap、プラグインの取得・更新、git 系ピッカー | 必須 |
| PowerShell (pwsh 推奨) | Windows の `shell`。外部コマンドと端末が全部これを通る | Windows で必須 |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | grep ピッカーと `grepprg` | 必須 |
| [fd](https://github.com/sharkdp/fd) | ファイルピッカーと explorer | Windows で必須 / Linux では推奨 |
| C コンパイラ (gcc または MSVC の cl) | treesitter パーサーのビルド | 必須 |
| curl / tar / gzip / unzip | treesitter と Mason の取得・展開 | 必須 |
| [Node.js](https://nodejs.org/) (node + npm) | Mason が npm で入れる LSP・整形ツール、Markdown プレビュー | 必須 |
| Nerd Font ([HackGen Console NF](https://github.com/yuru7/HackGen)) | アイコン表示と `guifont` | 実質必須 (無いと記号が豆腐になる) |
| ibus + ibus-anthy | 日本語入力 (Linux)。global engine を切り替える | Linux で必須 |
| [zenhan](https://github.com/iuchim/zenhan) または im-select | 日本語入力 (Windows) | 任意 (無ければ IME 連携のみ無効) |
| lazygit | `<leader>gg` | 任意 (無ければキーマップが定義されないだけ) |
| ネットワーク | 初回のプラグイン取得、Mason、treesitter パーサー | 初回のみ必須 |

**不要なもの** — fzf (ピッカーは snacks.nvim の Lua 実装。`:checkhealth lazyvim` が警告を
出すが機能には影響しない)、telescope とその C ビルド (使っていない)、make、Python、
win32yank (Neovim の Windows ビルドに同梱済み)。

### 選択した方針

**Neovim の入手経路** (Linux):

| 経路 | 状況 | 採否 |
|---|---|---|
| **Homebrew** | x86_64 / aarch64 ともボトルがあり、ソースビルドを待たずに最新版が入る | **採用** |
| EPEL の `neovim` | 0.10.1。LazyVim が要求する 0.11.2 に届かない | 不採用 |
| 公式リリースの tar.gz | `nvim-linux-x86_64.tar.gz` / `nvim-linux-arm64.tar.gz` を展開して PATH を通す | 不採用 (更新が手作業) |
| AppImage | **FUSE を必要とする**。コンテナや FUSE の無い環境では `fuse: device not found` で起動しない (`--appimage-extract` で展開して `squashfs-root/AppRun` を使う回避策はある) | 不採用 |

**パッケージマネージャ** — Windows は scoop を使う (管理者権限が要らず、すべて
`%USERPROFILE%\scoop` に収まるため)。winget や手動インストールでも構わないが、その場合は
**各コマンドが PATH に載っていること**だけ確認する。この設定はコマンドの場所を一切
ハードコードせず、`executable()` で PATH を見て機能を出し入れする。

### 手順の補足

#### 手順 0: 変数について

`NVIM_CONFIG` は clone 先を書くためだけのもの。Neovim 自身は `$XDG_CONFIG_HOME/nvim`
(未設定なら `~/.config/nvim`) / `%LOCALAPPDATA%\nvim` を見るので、**変数を変えただけでは
読み込み先は変わらない**。別の場所に置くなら `XDG_CONFIG_HOME` か `NVIM_APPNAME` を設定する。

`REPO_URL` を HTTPS にしてあるのは、SSH 鍵を GitHub に登録していない新しいマシンでは
`git@github.com:` 形式が `Host key verification failed` で失敗するため。
このリポジトリは public なので鍵は要らない。

#### 手順 1: パッケージマネージャの選択

Homebrew の公式インストーラは `/home/linuxbrew/.linuxbrew` に入れる (このパスに入る場合だけ
ボトルが使える)。**root で実行してはいけない。**

★ Homebrew を入れると `python@3.x` が依存として link されることがあり、そうなると
**ibus-anthy が起動できなくなって OS 全体で日本語が打てなくなる**。症状と対処は
[つまずきやすい点](#つまずきやすい点)にある。

#### 手順 2: 必須コマンドについて

- **EPEL が先に要る** — `ripgrep` と `fd-find` は AlmaLinux の base リポジトリに無い。
  `epel-release` を入れずに実行すると `Unable to find a match: ripgrep fd-find` で止まる。
- **`unzip` は必須** — Mason は zip 配布のツール (`stylua` など) の展開に使う。無いと
  **そのツールだけ**が静かに入らず、他は入るので気付きにくい。
- **Windows の curl / tar / gzip** — `curl` と `tar` は Windows 11 が
  `C:\Windows\System32` に同梱している。`gzip` は同梱されないが、Git for Windows
  (`C:\Program Files\Git\usr\bin`) が `unzip` ともども持っている。Mason はこれらが
  無いとツールのダウンロードに失敗する。
- **C コンパイラ** — nvim-treesitter は各言語のパーサーを**手元で C としてコンパイル**する
  ため、無いとハイライトが一切効かない。`scoop install gcc` を済ませていれば LazyVim が
  PATH の `gcc` を見つけて `$CC` に設定する。scoop を使わないなら
  `winget install --id=BrechtSanders.WinLibs.POSIX.UCRT` が手軽。Visual Studio Build Tools を
  入れているなら `cl.exe` も自動検出される。
- **node + npm** — Mason が `markdownlint-cli2` / `markdown-toc` / `bash-language-server` /
  `json-lsp` / `yaml-language-server` を npm パッケージとして入れる。つまり
  **node を消すと Markdown の lint と整形が丸ごと止まる**。`markdown-preview.nvim` も
  プリビルド版を入れていない間は node で動く。
- **Deno は不要** — 日本語のローマ字検索 (Migemo) は純 Lua の luamigemo が辞書ごと
  同梱しているため、外部ランタイムもネットワークも要らない。

#### 手順 3: Neovim の入手経路

経路の比較は[選択した方針](#選択した方針)にある。下限の 0.11.2 は LazyVim の要求で、
下回ると `:checkhealth lazyvim` がエラーを出す。

#### 手順 4: IME 連携の前提

Neovim から ibus への通信には `busctl` (systemd 同梱) か `gdbus` (glib2 同梱) を使う。
どちらか 1 つあればよく、通常はどちらも既に入っている (`gdbus` があれば OS 側の IME 切り替えも
検知できるので、lualine の `あ` / `A` 表示がズレない)。

GNOME 側の設定が 2 つとも要る理由:

- **入力ソースに「英語 (US)」を足す** — Neovim は global engine を `anthy` ↔ `xkb:us::eng` で
  切り替えるため、両方が GNOME の入力ソースとして登録されている必要がある
  (gnome-shell が管理外のエンジンを巻き戻すのを防ぐ)。
- **anthy の `on_off` から `Ctrl+J` / `Ctrl+space` を外す** — これは anthy *内部* の
  ひらがな⇔Latin モードを切り替えるもので、D-Bus から観測できない。残したままだと
  lualine の表示が実際とズレるうえ、`Ctrl+J` が anthy に食われて Neovim の `<C-j>` が届かない。

実装と運用上の注意 (変換中の `<Esc>` は 2 回、nvim を 2 つ起動したときの既知の制限など) は
[README の日本語入力・検索](../README.md#日本語入力検索)にある。

#### 手順 5: フォントと端末

WezTerm を使う場合は `treat_east_asian_ambiguous_width_as_wide` を既定 (false) のままに
しておく。Neovim 側の `ambiwidth` を既定 (single) のままにしてあり、**片方だけ変えると
`○` `±` `①` などを含む行の桁が丸ごとずれる** (理由は `lua/config/options.lua` のコメント)。

#### 手順 6: clone 先と `:Lazy restore`

lazy.nvim は初回に各プラグインの**最新コミット**を取ってくる。`:Lazy restore` をやらないと
別マシンと違うバージョンで動くことになる。運用方針は
[README の lazy-lock.json の運用](../README.md#lazy-lockjson-の運用)を参照。

#### 手順 7: headless での確認

スクリプトで確認したい場合は headless でも同じことができる。`!` を付けないと
`:Lazy sync` は待たずに戻り、`+qa` が取得途中のジョブを殺す。

```sh
nvim --headless "+Lazy! sync" +qa      # 初回導入
nvim --headless "+Lazy! restore" +qa   # lazy-lock.json に揃える
nvim --headless "+Lazy! load mason.nvim nvim-treesitter" \
     "+checkhealth lazyvim" "+w! /tmp/health.txt" +qa && grep ERROR /tmp/health.txt
```

ただし headless には UI が無いため `UIEnter` が発火せず、それを待つ `VeryLazy` も発火しない。
**`lua/config/autocmds.lua` (IME 連携・CJK スペル・保存時整形の登録) は読み込まれない**ので、
これらの確認は通常どおり `nvim` を起動して行うこと。

### つまずきやすい点

**一部の Mason ツールだけが入らない (`stylua` など)** — `unzip` が無い。Mason は zip で
配布されるツールの展開に `unzip` を使い、無いと**そのツールだけ**静かに失敗する。
`:Mason` で状態を確認し、`sudo dnf install unzip` の後に入れ直す。

**treesitter のハイライトが一切効かない** — C コンパイラが見つかっていない。
`:checkhealth lazyvim` の `nvim-treesitter` 節で `C compiler` を確認する。Windows で `gcc` を
入れた直後は PATH が反映されていないことがあるので、端末を開き直してから `nvim` を起動する。

**ファイルピッカーが空のまま** — `fd` も `rg` も無い。Linux には `find` へのフォールバックが
あるが **Windows では無効**なので、どちらかを必ず入れること。

**保存しても Markdown が整形されない / lint が出ない** — `markdownlint-cli2` と `markdown-toc` は
npm パッケージなので、node を入れ替えたり消したりすると Mason の導入済みツールごと壊れる。
`:Mason` で状態を見て、`:MasonInstall markdownlint-cli2 markdown-toc` で入れ直す。

**`/` からの日本語検索が効かない** — `:checkhealth luamigemo` で同梱辞書と LuaJIT を確認する。
入力がローマ字として読めない場合 (`search` のような英単語、空白や記号を含む) は
意図的に変換しない仕様なので、まず `/kensaku<CR>` のような純粋なローマ字で試す。

**アイコンが豆腐 (□) になる** — 端末側のフォントが Nerd Font になっていない。
`guifont` は GUI クライアント専用で、端末には効かない。

**全角記号を含む行の桁がずれる** — Neovim の `ambiwidth` と端末の East Asian Ambiguous 幅の
設定が食い違っている。この設定は両方 narrow 側 (`single` /
`treat_east_asian_ambiguous_width_as_wide=false`) で揃えてあるので、端末側だけを wide に
変えないこと。

**日本語が一切入力できない (Linux)** — ibus のエンジン自体が起動に失敗している可能性がある。
Neovim の中だけでなく OS 全体で打てなくなるのが特徴。ibus は engine の起動に失敗しても
黙って英数のままになるため、`ibus engine` は `anthy` を返すのに変換だけが効かない、という
見え方になる (engine プロセスはフォーカス時に遅延起動するので、`ps` に `ibus-engine-anthy` が
居ないこと自体は異常の証拠にならない)。まずエンジンを直接起動してみる。

```sh
/usr/libexec/ibus-engine-anthy --xml | head -3   # エンジン定義が出れば起動できている
```

`ModuleNotFoundError: No module named 'gi'` が出る場合は、`python3` がシステム
(`/usr/bin/python3`) ではなく Homebrew のものに解決されている。`/usr/libexec/ibus-engine-anthy` は
`exec python3 …` と PATH 頼りで起動する一方、Homebrew の python には PyGObject (`gi`) が
入っていないため、`brew` が `python@3.x` を他の formula の依存として link した瞬間 (PATH の
先頭に入るため) エンジンが死ぬ。

```sh
which python3                 # /home/linuxbrew/... ならこれが原因
brew unlink python@3.14       # brew の bin から python3 の symlink を外す
ibus restart
```

`brew info --json=v2 python@3.14` の `installed_on_request` が `false` (= 依存として入っただけで
自分で入れたわけではない) なら unlink して構わない。依存する formula は shebang に
Cellar/opt の絶対パスを持つので影響を受けない。**`brew upgrade` で再 link されると同じ症状が
再発する**ため、その時はもう一度 unlink する。

### 参照

- [LazyVim のインストール](https://lazyvim.github.io/installation) — 要求される外部コマンドと初回起動の流れ
- [lazy.nvim](https://lazy.folke.io/) — `:Lazy restore` と `lazy-lock.json` の扱い
- [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) — `/home/linuxbrew/.linuxbrew` に入れる理由とボトルの条件
- [scoop](https://scoop.sh/) — 管理者権限なしで `%USERPROFILE%\scoop` に入れる
- [luamigemo](https://github.com/delphinus/luamigemo) — ローマ字検索 (Migemo) の純 Lua 実装。同梱辞書のライセンスもここ
- [ibus-anthy](https://github.com/ibus/ibus-anthy) — `on_off` などのキー割り当て
- [../README.md](../README.md) — この設定で何ができるか、IME 連携の設計と運用上の注意
