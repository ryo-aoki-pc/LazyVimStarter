# LazyVim の設定のロールバックと注意点

[手順書（Neovim のセットアップ）](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md)・[検証記録](../verification/setup.md)・[参考資料](../reference/setup.md)

- 「AlmaLinux 導入の手順 N」は正本の[LazyVim の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の設定を導入する)、「Windows 導入の手順 N」は[Windows 11 で LazyVim の設定を導入する](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の設定を導入する)の手順を指す。「この節の手順 N」はこの文書の手順

## ロールバック

- この設定とプラグインを消し、[AlmaLinux 導入の手順 3](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の設定を導入する) / [Windows 導入の手順 3](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の設定を導入する) で退避したものを戻す
- AlmaLinux 10 はこの節の手順 1〜4、Windows 11 はこの節の手順 5〜7 を、上から順に貼る
- setup-notes の[端末とエディタを消す](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/almalinux-setup.md#端末とエディタを消す) (AlmaLinux 10)・[エディタとシェルのツールを消す](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/extra/windows-setup.md#エディタとシェルのツールを消す) (Windows 11) から来たときは、そこに書いたとおり、この節の手順 4・7 は行わない (Neovim・lazygit・フォントは、そちらの項で消す)
- dnf / Homebrew / scoop で入れた共通のコマンド (git・ripgrep・fd・node など) と Homebrew 本体は、ほかでも使うので残す
- GitLab プレビューのトークンを設定していたら、[設定を消す手順](#gitlab-プレビューの設定を消す)を行う
- 検証した範囲は [検証記録](../verification/setup.md)を参照する

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
   - 入力ソースは既定 (空) に戻る。導入の前の値に戻すなら、[AlmaLinux 導入の手順 7](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の設定を導入する) の最初の行に出た値を `/usr/bin/gsettings set` で書く

1. AlmaLinux 10 で、Homebrew で入れたものも消すときだけ、消す。

   ```bash
   brew uninstall neovim lazygit
   brew uninstall --cask font-hackgen-nerd
   brew autoremove
   ```

   - `brew uninstall` が、Neovim の依存 7 つ (`luajit` など) のうち、ほかに使われていないものも消す (`==> Autoremoving 7 unneeded formulae:`)
   - `brew autoremove` は、それでも残った不要な依存を消す
   - ripgrep と fd はほかでも使うので残す。消すなら 1 行目に足す
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

## GitLab プレビューの設定を消す

1. AlmaLinux 10 で、設定を消すときは、`~/.bashrc` から消す。

   ```bash
   sed -i '/^export GITLAB_\(TOKEN\|HOST\)=/d' ~/.bashrc
   ```

   - GitLab の側でも、「アクセストークン」からそのトークンを取り消す
   - 開いたままの端末には値が残る。端末を開き直す

1. Windows 11 で、(この節の手順 1 の代わりに) 設定を消すときは、ユーザーの環境変数から消す。

   ```powershell
   foreach ($n in 'GITLAB_TOKEN', 'GITLAB_HOST') { [Environment]::SetEnvironmentVariable($n, $null, 'User') }
   ```

   - プロンプトが戻るまで 4 秒ほどかかる (環境変数を 2 つ消す)
   - GitLab の側でも、「アクセストークン」からそのトークンを取り消す

## GNOME の上部バーの拡張を戻す

1. 元に戻すときは、拡張を無効にして、つなぎを外す。

   ```bash
   gnome-extensions disable ibus-engine-follow@ryo-aoki-pc.github.com
   rm ~/.local/share/gnome-shell/extensions/ibus-engine-follow@ryo-aoki-pc.github.com
   ```

   - 上部バーは、Neovim が切り替えた後もそれまでの入力ソースのまま残るようになる (この節を行う前と同じ)

## 必要なもの一覧

| 依存 | 用途 | 必須? |
| --- | --- | --- |
| [Neovim](https://neovim.io/) 0.12 以上 | 本体。LazyVim の下限は 0.11.2 だが、`lazy-lock.json` の nvim-treesitter が 0.12 を要る | 必須  |
| git | lazy.nvim の bootstrap、プラグインの取得・更新、git 系ピッカー | 必須 |
| PowerShell (pwsh 推奨) | Windows の `shell`。外部コマンドと端末が全部これを通る | Windows で必須 |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | grep ピッカーと `grepprg`、`/` の `<Tab>` で出す Migemo の候補 | 必須 |
| [fd](https://github.com/sharkdp/fd) | ファイルピッカーと explorer | Windows で必須 / Linux では推奨 |
| C コンパイラ (gcc または MSVC の cl) | treesitter のパーサーのビルド | 必須 |
| tree-sitter CLI | treesitter のパーサーのビルド。PATH に無ければ LazyVim が Mason で入れる | 必須 (自動で入る) |
| curl / tar / gzip / unzip | treesitter と Mason の取得・展開。curl は GitLab プレビューが GitLab の API を呼ぶのにも使う (8.3 以上) | 必須 (Windows 11 は同梱の curl と tar だけでよい。[Windows の外部コマンドの説明](../reference/setup.md#windows-11-で-lazyvim-の設定を導入する--手順-5-補足-windows-の外部コマンド)) |
| [Node.js](https://nodejs.org/) 22 以上 (node + npm) | Mason の LSP・lint と、Markdown の整形器 [md-format](https://github.com/ryo-aoki-pc/md-format) | 必須 |
| Nerd Font ([HackGen Console NF](https://github.com/yuru7/HackGen)) | アイコン表示と `guifont` | 実質必須 (無いと記号が豆腐になる) |
| ibus + ibus-anthy、`busctl` か `gdbus` | 日本語入力 (Linux)。global engine を切り替える | Linux で必須 |
| [zenhan](https://github.com/iuchim/zenhan) または im-select | 日本語入力 (Windows) | 任意 (無ければ IME 連携のみ無効) |
| [Neovide](https://neovide.dev/) 0.16 以上 | GUI クライアント。IME の未確定文字列の表示には Neovim 0.12 以上も要る | 任意 (端末で使うなら不要) |
| lazygit | `<leader>gg` | 任意 (無ければキーマップが定義されないだけ) |
| GitLab の個人アクセストークン (`read_api`) | GitLab プレビューで、GitLab 本体に描かせる ([トークンの節](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の-gitlab-プレビューを設定する)) | 任意 (無ければ近似表示になる) |
| ブラウザ | GitLab プレビューのページ | 任意 (プレビューを使うときだけ) |
| wl-clipboard (`wl-paste`) | `<leader>ci` での画像の貼り付け (Linux) | 任意 (無ければ `<leader>ci` だけが使えない) |
| GNOME Shell 49 | [上部バーの節](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の-ime-連携に-gnome-の上部バーを合わせる)の拡張 (上部バーと Super+Space の順番を Neovim の IME の切り替えに合わせる) | 任意 (無ければ上部バーが Neovim の切り替えに付いてこないだけ) |
| OSC 52 の書き込みに対応した端末 (WezTerm の nightly など) | SSH 越しのヤンクを手元のクリップボードに入れる ([SSH の節](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-のヤンクを-ssh-越しに手元へ送る)) | 任意 (SSH で使うときだけ) |
| ネットワーク | 初回のプラグイン取得、Mason、treesitter のパーサー。GitLab プレビューでは GitLab と cdn.jsdelivr.net | 初回のみ必須 |

- **不要なもの**: fzf (ピッカーは snacks.nvim の Lua 実装。`:checkhealth lazyvim` が警告を出すが機能には影響しない)、telescope とその C ビルド、make、Python、Deno、win32yank (Neovim の Windows ビルドに同梱済み)、プレビュー用の node のアプリ (GitLab プレビューは Neovim の中の HTTP サーバーと curl だけで動く)、SSH 越しのクリップボードのための X11 転送・xclip・lemonade (OSC 52 で端末に渡す)

## 注意点

- **Windows で `nvim` が起動しない (`VCRUNTIME140.dll が見つからない` / `0xC0000135`)**: Visual C++ のランタイムが入っていない
  - scoop の `neovim` は `VCRUNTIME140.dll` を同梱しない (`nvim.exe` と `lua51.dll` が読み込む)。[Windows 導入の手順 5](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#windows-11-で-lazyvim-の設定を導入する)の 1 行目が、`System32\vcruntime140.dll` が無いときだけ `vcredist2022` を入れる。手順 6 の `nvim --version` で確かめる
  - `vcruntime140.dll` があるのに手順 6 の `nvim --version` が通らないときは、`scoop install vcredist2022` を条件を付けずに貼り、今の版のランタイムを入れる (手順 5 の 1 行目はファイルの有無だけを見て、版は見ない)。`already installed` と出たら、`scoop uninstall vcredist2022` の後にもう一度貼る (uninstall で消えるのはインストーラーだけで、ランタイムは残る)
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
  - 整形器は md-format を setup-notes の md-format の導入 ([AlmaLinux 10](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/almalinux-setup.md#md-format-を導入更新する) / [Windows 11](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/windows-setup.md#md-format-を導入更新する)) で入れる。`md-format (mdfmt) が導入されていません` と出たら、まだ入れていない
  - md-format の clone で `node scripts/setup.mjs --check` を実行すると、導入の状態 (版・依存・起動役・PATH) を確かめられる
  - `HTML の整形器 (js-beautify) を読み込めません` と出たら、md-format の導入が途中で壊れている。導入スクリプトを実行し直す
  - lint の診断用は `:Mason` で状態を見て、`:MasonInstall markdownlint-cli2` で入れ直す
  - `:ConformInfo` を開く。`Formatter 'mdfmt' timeout` は整形の時間切れで、ツールの未導入とは区別する
  - Markdown / MDX の整形上限は 10 秒。ほかのファイルは既定の 3 秒
- **GitLab プレビュー (`<leader>cp`) が `近似表示` になる**: ページの上のバナーに理由が出る
  - `GITLAB_TOKEN が未設定`: [トークンの節](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の-gitlab-プレビューを設定する)を行い、端末 (と Neovide) を開き直す
  - `トークンが拒否された (HTTP 401)`: トークンの期限切れ、スコープ (`read_api`)、`GITLAB_HOST` の違いを確かめる。直したら `:GitLabPreview` で送り直す
  - `GitLab の API が見つからない (HTTP 404)`: `GITLAB_HOST` が GitLab を指していない。サブパスで動かしている GitLab は `https://example.com/gitlab` まで書く
  - `GitLab に接続できない (curl: …)`: ネットワーク・プロキシ (curl は `HTTPS_PROXY` を見る)・社内の CA (Windows の curl は OS の証明書ストアを使う) を確かめる。30 秒たつと送り直す
  - `option --variable: is unknown` を含むとき: curl が 8.3 より古い。Linux では新しい curl を入れる
- **GitLab プレビューで `#123` などがリンクにならない**: git の remote (origin) のホスト名が `GITLAB_HOST` と違うと、プロジェクトを付けずに描かせる
  - SSH の設定の別名 (`Host` の名前) を使った remote は、ホスト名が一致しない。`git remote -v` で確かめる
- **`<leader>ci` で画像を貼り付けられない**: `:ImgClipDebug` で、使ったコマンドと出力を見る
  - Linux では `wl-clipboard` が要り、Wayland のセッションで起動した Neovim だけが使える (tmux の中では `WAYLAND_DISPLAY` が引き継がれないことがある)
  - `Content is not an image.` は、クリップボードの中身が画像ではないとき。Windows では、PC のロック中はクリップボードを読めない
- **SSH 越しにヤンクしても手元のクリップボードに入らない**: [SSH の節](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-のヤンクを-ssh-越しに手元へ送る)の手順 1 で、`SSH_CONNECTION` と `OSC 52 (copy only)` が出るかを確かめる
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
  - 初めてのマシンの初回起動でも変わる ([lock 復元の説明](../reference/setup.md#lazyvim-の設定を導入する--手順-10-補足-lazy-lockjson-を戻してから-restore-する理由))
- **日本語のときに `<C-j>` で英数に戻らない (Linux)**: Anthy の `on_off` に `Ctrl+J` が残っていて、Neovim に届く前に Anthy の中のひらがなと英字が切り替わっている
  - 打った英字が、そのまま出たり「あ」になったりと、日本語の中で入力が揺れるのが特徴
  - AlmaLinux 導入の手順 7〜9 を Homebrew の `gsettings` で実行すると、dconf ではなく `~/.config/glib-2.0/settings/keyfile` に書かれて効かない
  - `/usr/bin/gsettings` で確かめ、`Ctrl+J` が残っていれば手順 8・9 を貼り直す (今の手順は `/usr/bin/gsettings` を使う)

  ```bash
  /usr/bin/gsettings get org.freedesktop.ibus.engine.anthy.shortcut default | grep -o "'on_off': <\[[^]]*\]>"
  ```

- **GNOME の上部バーが Neovim の `あ` / `A` とずれる・最初の Super+Space が空振りする**: GNOME Shell は、Neovim が切り替えた engine に上部バーを合わせない
  - [上部バーの節](https://github.com/ryo-aoki-pc/setup-notes/blob/main/docs/neovim.md#lazyvim-の-ime-連携に-gnome-の上部バーを合わせる)の拡張を入れると揃う。入れない場合は、Neovim の中では `<C-j>` を使う (README の補足)
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
