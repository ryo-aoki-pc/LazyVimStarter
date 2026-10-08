# LazyVim 導入の検証記録

以下は既存文書から移した記録。本文の「本書」「この文書」と手順番号は、記録元の手順書を指す。新しく検証した記録ではない。
ただし、「付録: Windows 導入の手順 6 の VC++ ランタイムを条件付きにした記録 (2026-10-08)」は新しく検証した記録 (Windows では実行していない)。

手順は [setup.md](../setup.md)、背景説明は [補足資料](../reference/setup.md) を参照する。日付・対象の版・実施範囲は各記録に記載する。

### EPEL が要る理由の検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 2 に対応する。

- 最後の `Many EPEL packages require the CodeReady Builder (CRB) repository.` は、この節で入れるものには当てはまらない (CRB を有効にせずに通した)

### dnf で入れるものの検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 3 に対応する。

- コンテナ (最小構成の `almalinux:10`) での実測は、101 個を入れて 4 個を更新した (git の依存の perl など。`wl-clipboard` を足す前の数)。GNOME の PC ではもっと少ない

### Homebrew を使う理由と導入先の検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 8 に対応する。

- `Next steps` の `sudo dnf group install development-tools` は、この設定には要らない (入れずに通した)

### brew の確認の検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 10 に対応する。

- 検証した Homebrew 7.0.7 は、依存のある formula を入れる前に確認を求めた (`==> Would install 2 formulae:` → `==> Would install 7 dependencies for neovim:` → `[y/n]`)

### Neovim の版の検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 11 に対応する。

- ただし `lazy-lock.json` に記録した nvim-treesitter (main ブランチ) は Neovim 0.12 以上を要求する。0.11 系では試していない

### 入力ソースを 2 つとも登録する理由の検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 13 に対応する。

- 英数のエンジン名は `ime.lua` の中で `xkb:us::eng` に固定してある。入力ソースを `('xkb', 'jp')` にすると、Neovim が英数に戻すたびに US 配列のエンジンになる (コードから読んだもので、JIS 配列では試していない)

### 初回起動で入るものの検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 17 に対応する。

- コンテナではパーサーの取得がプロキシに拒まれた ([付録](#付録-コンテナでの検証記録-2026-09-28))。AlmaLinux 10 の実機では、開いてから 13 秒で 30 個が入り、ハイライトが効いた ([付録](#付録-almalinux-10-の実機での導入と取り込みの検証記録-2026-09-29))

### 機能の確かめ方の検証記録

元の説明は [AlmaLinux 10 に導入する (1 度だけ)](../setup.md#almalinux-10-に導入する-1-度だけ)の手順 19 に対応する。

- コンテナでは ibus-daemon を `--panel disable` で起動して、`<C-j>` で `ibus engine` が `anthy` に、`<Esc>` で `xkb:us::eng` に変わるのを確かめた。アイコンの見た目は確かめていない

### トークンの置き場所の検証記録

元の説明は [GitLab プレビューのトークンを設定する (任意)](../setup.md#gitlab-プレビューのトークンを設定する-任意)の手順 3 に対応する。

元の説明は [GitLab プレビューのトークンを設定する (任意)](../setup.md#gitlab-プレビューのトークンを設定する-任意)の手順 1 に対応する。

- 時間がかかるのは、変えたことを開いている全てのウィンドウに知らせ終わるまで戻らないため (検証した PC では 1 回 2 秒ほど)

### 仕組みと、手元から Neovim への向きの検証記録

元の説明は [SSH 越しのヤンクを手元のクリップボードに送る (任意)](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 2 に対応する。

- 手元が Windows のときは、WezTerm の nightly と Windows Terminal で確かめた。ssh は Windows の OpenSSH (`ssh.exe`) でも Git for Windows の `ssh` でもよい ([付録](#付録-windows-11-の実機での未確認項目の検証記録-2026-09-30))

## 手順冒頭の検証範囲

> [!WARNING]
> **2026-10-08 に、Windows 導入の手順 6 の VC++ ランタイムの導入を、`System32\vcruntime140.dll` が無いときだけにした。この変更は Windows では流していない** (Linux の PowerShell 7.6.6 で、ブロックの構文と分岐だけを確かめた。[記録](#付録-windows-導入の手順-6-の-vc-ランタイムを条件付きにした記録-2026-10-08))。
>
> **2026-10-06 に現行 `ae7f049` を、新規 AlmaLinux 10.2 の x86_64 VM で公開 URL から新規導入した**。CLI の前提・lock 復元・Mason 11 個・パーサー 30 個・検索・保存時の整形を確認し、遅い VM の Markdown 整形の待ち時間を修正した（[今回の CLI 記録](#付録-新規-almalinux-102-vm-での-cli-導入整形の再検証2026-10-06)）。別の新規 GNOME VM でも入力ソース・通常 GUI・IBus の Ctrl+J / Esc・検索 sticky・アイコン・修正後の保存を確認した（[今回の GUI 記録](#付録-現行手順を別のクリーン-vm-の-gnome-で再検証-2026-10-06)）。物理キー・上部バー拡張・画像貼り付け等は今回未実施。以下は過去の検証範囲。
>
> **AlmaLinux 10 の手順は x86_64 のコンテナで通した。GNOME の実機では、導入済みの PC で AlmaLinux 導入の手順 16〜19 と取り込みの手順 1 だけを通した** (手順 1〜15 は、システムを変えずに到達点を確かめただけ)。aarch64 では通していない。**上部バーの節は、画面の無い gnome-shell でだけ確かめた** (本物のログインでは通していない)。**Windows 11 の手順は実機とクリーンインストールした VM で通した** (scoop も Git for Windows も PATH に無い状態からの通しと、本物の IME を含む)。VM では VC++ ランタイム不足の起動失敗を再現し、手順 6 に導入を追加して起動できることを確かめた。**GitLab プレビューは、本物の GitLab では表示できることだけを確かめた** (記法ごとの見え方は模擬の API で確かめた)。**SSH 越しのクリップボードは、GNOME の画面では確かめていない** (AlmaLinux 10 の実機で、WezTerm の nightly を画面の無い mutter の上で動かし、ssh して確かめた。Windows からは、WezTerm の nightly と Windows Terminal で WSL の AlmaLinux 10 に ssh して確かめた)。範囲は[対象と検証環境](#対象と検証環境)。

### 手順内の記述

- `brew autoremove` は、それでも残った不要な依存を消す (検証では何も残っていなかった)

### 導入の実施範囲

- この節の手順は、Windows 11 Pro の実機とクリーンインストールした Windows 11 Enterprise Evaluation の VM で Windows PowerShell 5.1 に渡して通した (scoop と git が無い状態から、手順 2 を含めて。VM では VC++ ランタイムも無かった。範囲は[対象と検証環境](#対象と検証環境))

### 対象と検証環境

- **目的**: 新しいマシンで、この Neovim 設定 (日本語の入力・検索と Markdown 執筆の強化) を動かす。設定そのものの説明は [README](../../README.md)
- **進め方**: 外部コマンドを先に揃え、この設定を clone し、プラグインを `lazy-lock.json` の版に揃えてから初回起動する
  - 変数は無い。読者が書き換える値も無い (GitLab プレビューのトークンの節だけは、トークンと URL を貼った後に入力する)
  - AlmaLinux 10 は dnf + EPEL と Homebrew、Windows 11 は scoop で入れる
- **状態**:
  - **2026-10-06 に `ae7f049` を新規 AlmaLinux 10.2 の x86_64 VM で新規導入し、CLI の前提・lock・Mason 11 個・パーサー 30 個・検索・保存を確認した**。Markdown 整形は遅い VM で 3 秒の上限を超えたため、Markdown / MDX だけ 10 秒へ修正して再実行した（[今回の CLI 記録](#付録-新規-almalinux-102-vm-での-cli-導入整形の再検証2026-10-06)）。以下の記録は、それぞれの過去の環境で確認した範囲を示す
  - **別の新規 GNOME VM で現行の手順 13〜19 も通した**。入力ソース・Anthy キーの保持・通常 WezTerm GUI・Mason 11 個 / パーサー 30 個・Migemo / Tab・修正後 `:w`・IBus の Ctrl+J / Esc と検索 sticky・アイコンを実 evdev keycode と PNG で確認した（[今回の GUI 記録](#付録-現行手順を別のクリーン-vm-の-gnome-で再検証-2026-10-06)）。health は fzf の WARNING だけ。物理キー・上部バー拡張・画像貼り付け等は今回未実施
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
    - **確かめていないこと** (3 つとも、2026-09-30 に確かめた。下の記録):
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
  - **SSH 越しのクリップボード ([SSH の節](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)) は、x86_64 のコンテナで、tmux を手元の端末の代わりにして確かめた (2026-09-29)** ([付録](#付録-ssh-越しのクリップボードの検証記録-2026-09-29))
    - Neovim 0.12.5 (公式の Linux 版のリリース) にこの設定とプラグイン 38 個を入れ、`SSH_CONNECTION` を付けて tmux の中で起動した。tmux (`set-clipboard on`) が OSC 52 を受けて作るペーストバッファを、手元のクリップボードの代わりに見た
    - 確かめたこと:
      - 変更前は、tmux の中の SSH のシェルで `yy` も `"+yy` も OSC 52 を出さない (`clipboard` が空で、tmux では OSC 52 が検出されず、クリップボードの提供元が無い)
      - 変更後は、`yy`・`"+yy`・矩形・文字単位のヤンクで OSC 52 が出て、日本語を含めて中身が一致する。`p` は待たずに元の形 (行単位・矩形) で貼る
      - まだ何も送っていないときの `p` は、待たずに、前に使ったレジスタから貼る (無ければ `E353`)。`SSH_CONNECTION` が無ければ、OSC 52 を出さない (これまでどおり)
      - [SSH の節](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 1・2 のブロック (手順 2 は tmux の中で、`yy`・`p`・`:set clipboard?`)
    - 実物の WezTerm と AlmaLinux 10 での通しは、次の記録で確かめた
  - **SSH 越しのクリップボードは、AlmaLinux 10 の実機で、WezTerm の nightly から ssh して通した (2026-09-29)** ([付録](#付録-almalinux-10-の実機での-ssh-越しのクリップボードの検証記録-2026-09-29))
    - AlmaLinux 10.2 (x86_64) の上で、WezTerm 20260928 (nightly。利用者の設定ファイルのまま) を画面の無い mutter 49.4 で動かした
    - その WezTerm から sshd に ssh し、ログインしたシェルに[SSH の節](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)の**手順 1・2 のブロックをそのまま貼って**通した
    - 確かめたこと:
      - 手順 1 の出力 (`SSH_CONNECTION` の 4 つの値と `OSC 52 (copy only)`)、手順 2 の `yy`・`p`・`:set clipboard?`
      - 続けて 5 回ヤンクしても、毎回その内容が手元のクリップボードに入ること
      - 大きな範囲の `ggyG` (日本語の 8 万行、6.9 MB まで) が、ファイルとバイト単位で一致すること。矩形・文字単位の形
      - 変更前は `yy` が入らず、`"+p` が 10 秒待って失敗すること (`"+yy` は入る。WezTerm の nightly は DA1 に `52` を出すので、noice があっても検出される)
    - **確かめていないこと**:
      - Windows からの ssh (2026-09-30 に、WSL の AlmaLinux 10 に対して確かめた。下の記録)
      - GNOME にログインした画面の WezTerm (同じ版の mutter を、画面無しで動かして代えた)
      - PAM を通すシステムの sshd でのログイン (同じ `/usr/sbin/sshd` を、検証用の設定で自分のユーザーのまま立てた。2026-09-30 に、WSL の AlmaLinux 10 で PAM を通す形も確かめた。下の記録)
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
      - [上部バーの節](../setup.md#gnome-の上部バーを-ime-連携に合わせる-任意)の拡張を、画面の無い gnome-shell 49.4 (閉じたセッションバスと自前の ibus-daemon) で。外から engine を切り替えるたびに、今の入力ソースが付いてきた
    - **確かめていないこと**:
      - 手順 1〜15 の実行と、ログインし直しての ibus の読み直し
      - 上部バーの節を、本物のログインで通すこと (拡張を入れて有効にしたが、ログインし直していない)。本物の Super+Space で空振りしなくなること
      - Super+Space で切り替えたときの、カーソルのすぐ下の表示 (フォーカスが戻ったときに出すように直した。本物のキーでは確かめていない)
      - 画面でのカーソルの色の見え方、トークンの節の AlmaLinux の手順と本物の GitLab、tmux の節 (カーソル色)
  - **Windows 11 の実機で、Windows で確かめていなかった項目を確かめた (2026-09-30)。利用者の離席中に、画面・本物の IME・クリップボードも使った** ([付録](#付録-windows-11-の実機での未確認項目の検証記録-2026-09-30))
    - 対象は `custom` の 3ca878f。設定とデータの置き場所は一時的な場所に差し替えた。scoop も一時的な場所に新しく入れ、scoop が書くユーザーの環境変数と実行ポリシーは、レジストリを差し替えて受けた
    - 確かめたこと:
      - scoop も Git for Windows も PATH に無い状態から、Windows 導入の手順 1〜11 (手順 2 の scoop の導入を含む)・更新の手順 2・ロールバックの手順 5〜7
      - 取り込みの手順 2 で、増えたプラグインを起動時に入れて lock が古い版で書き直される場合と、箇条書きの対処 (`checkout` して `restore` をもう一度)
      - flash の `s` (`s` → `nihon` → `;` → ラベルなど。端末と Neovide 0.16.2)、フォーカスが戻ったときのカーソルのすぐ下の表示、手順 11 の確認項目 (最新の設定で)
      - 本物の IME (Microsoft IME) と本物の zenhan: Neovide 0.16.2 と WezTerm の nightly で、`Ctrl+J` で IME が開閉し、`nihon` の未確定文字列 (Neovide はハンドラ経由でカーソル位置に描く) が変換・確定されること。IME が開いたままの `Ctrl+J` も Neovim に届く。キーは `SendInput` で入れた (IME を通る)
      - SSH 越しのクリップボード: WezTerm の nightly (Windows の OpenSSH と Git for Windows の ssh) と Windows Terminal 1.24 (Windows の OpenSSH) から WSL の AlmaLinux 10.2 に ssh し、[SSH の節](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)の手順 1・2 のブロックをそのまま貼って、`yy` が Windows のクリップボードに入ること。sshd は、自分のユーザーのまま立てたものと、PAM を通すもの (root)
    - 見つけて直したこと: scoop の git (`core.autocrlf=true` が既定) で clone すると、手順 8 の `git status --short` が `M lazy-lock.json` を出し続けた。`.gitattributes` で改行を LF に揃えた
    - **確かめていないこと**:
      - VC++ のランタイム (`VCRUNTIME140.dll`) が無い Windows 11 (`nvim.exe` は読み込むが、この PC にはシステムに入っている)
      - 物理キーボードでの打鍵 (`SendInput` で代えた)
      - SSH の接続先の、実機の AlmaLinux 10 と systemd の sshd.service (WSL の AlmaLinux 10 で代えた)
  - **クリーンインストールした Windows 11 の VM で導入を確かめた (2026-10-06)** ([付録](#付録-クリーンインストールした-windows-11-vm-での検証記録-2026-10-06))
    - 対象は `custom` の `f0d732d`。scoop・git・Neovim・VC++ ランタイムが無い新規 Windows 11 Enterprise Evaluation の複製に、通常の置き場所のまま導入した
    - ランタイム不足で Neovim が `0xC0000135` を返した。手順 6 に `scoop install vcredist2022` を追加し、x64・x86 の UAC を許可すると起動できた
    - 有効なプラグイン 38 個の HEAD が lock と一致し、`core.autocrlf=true` でも Git の変更表示は空で lock は LF。実 UI で Mason の 11 個、パーサー 30 個とハイライト、marksman の初期化を確認した
    - Windows Terminal と Microsoft IME で、日本語入力・`<C-j>`・Esc の英数化・検索の sticky と状態表示・`/kensaku`・Tab の補完・保存時の Markdown 整形・アイコンを確認した。キーは VirtualBox の仮想キーボードから入れ、OS の IME を通した。health は無視してよい `fzf` の WARNING だけだった
    - 更新・ロールバック・任意の節・Neovide は今回の VM では確認していない
  - **2026-10-08 に、Windows 導入の手順 6 の VC++ ランタイムを、`System32\vcruntime140.dll` が無いときだけ入れる形にした。Windows では流していない** ([付録](#付録-windows-導入の手順-6-の-vc-ランタイムを条件付きにした記録-2026-10-08))
    - Linux の PowerShell 7.6.6 で、ブロックの構文と、`scoop` をモックにした分岐 (ファイルが無ければ `vcredist2022` も入れ、あれば飛ばす) だけを確かめた
  - 以前の版の状態行は「AlmaLinux 10 の使い捨てコンテナで手順を頭から流して検証済み」だった。本書はシナリオに分けてコマンドも変えたので、上の記録で置き換える

| 項目 | AlmaLinux 10 | Windows 11 |
|---|---|---|
| 検証 | x86_64 のコンテナ (AlmaLinux 10.2) で通した。GNOME の実機では、手順 16〜19 と取り込みだけを通した | 実機 (Windows 11 Pro) では置き場所を差し替えて通し、クリーンな VM (Enterprise Evaluation) では通常の置き場所で導入を確認した |
| パッケージマネージャ | dnf + EPEL、Neovim・lazygit・フォントは Homebrew (7.0.7) | scoop |
| Neovim | Homebrew の `neovim` (0.12.5) | scoop の `neovim` (0.12.5) |
| IME | ibus 1.5.32 + ibus-anthy 1.5.17 (`busctl` / `gdbus` で制御) | zenhan 0.0.1 (任意。検証の多くはモックで、本物でも確かめた) |
| フォント | Homebrew の cask `font-hackgen-nerd` (2.10.0) | リリースの zip から手で入れる |
| 設定の置き場所 | `~/.config/nvim` | `%LOCALAPPDATA%\nvim` |

> [!NOTE]
> - 本書には変数が無い。設定の置き場所と clone 元の URL は、Neovim と GitHub が決める固定の値なので、コマンドに直接書いてある
> - 途中で作る値は `ANTHY_SHORTCUT` だけ ([AlmaLinux 導入の手順 14](../setup.md#almalinux-10-に導入する-1-度だけ) で作り、手順 15 で使う)
> - 出力例の中のユーザーのホームは `…` で省いてある。パスワードと鍵は扱わない。トークンは [GitLab プレビューのトークンの節](../setup.md#gitlab-プレビューのトークンを設定する-任意)でだけ扱い、貼った後に入力させる (文書には書かない)

### 完了時点の状態の測定・実施記録

| `~/.local/share/nvim/lazy` | プラグイン 38 個 (`lazy-lock.json` の版)。コンテナで 189 MB (markdown-preview.nvim を img-clip.nvim に替える前の計測) |

### 完了時点の状態の測定・実施記録

| `~/.local/share/nvim/mason` | Mason のツール 11 個。コンテナで 279 MB (markdown-toc を外す前の 12 個での計測) |

### 注意点の測定・実施記録

  - `~/.local/state/nvim/mason.log` に npm のエラーが残る。検証環境では、プロキシの CA を node に渡すまで `SELF_SIGNED_CERT_IN_CHAIN` で失敗した

### 注意点の測定・実施記録

  - AlmaLinux 10 の 1 CPU の新規 VM で、正常な単独整形にも約 3 秒掛かった。Markdown / MDX だけ上限を 10 秒へ広げて保存整形を再確認した。ほかのファイルは既定の 3 秒のまま

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

- **対象**: SSH のシェルで起動したときに、ヤンクを OSC 52 で手元のクリップボードに送る変更 (`lua/config/options.lua`) と、[SSH の節](../setup.md#ssh-越しのヤンクを手元のクリップボードに送る-任意)
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
  - Neovim を開いた時点で上部バーがずれていて、最初の Super+Space では engine が変わらなかった (すでに `xkb:us::eng` だった)。GNOME Shell 49.4 の `ui/status/keyboard.js` と `misc/ibusManager.js` を読むと、外からの engine の変更で「今の入力ソース」と Super+Space の順番 (MRU) を更新しない。そのため[上部バーの節](../setup.md#gnome-の上部バーを-ime-連携に合わせる-任意)の拡張を足した
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

### 付録: Windows 11 の実機での未確認項目の検証記録 (2026-09-30)

- **対象**: `custom` の 3ca878f (#37 のマージの後)。#31・#34〜#37 のうち Windows で確かめていなかったことと、[Windows 11 の付録](#付録-windows-11-の実機での検証記録-2026-09-29)の未確認事項 (本物の IME と zenhan・Neovide に本物の IME で打つこと・scoop の導入とロールバックの手順 7・scoop も Git for Windows も無い状態からの通し)
- **環境**: 上の付録と同じ Windows 11 Pro 10.0.26200 (x64)。scoop の neovim 0.12.5、Neovide 0.16.2、WezTerm 20260905-153129-092dcf70 (nightly。利用者の設定ファイルのまま)、Windows Terminal 1.24.11911.0、Microsoft IME
  - `LOCALAPPDATA` と `TEMP` を一時的な場所に差し替え、PATH をレジストリの値から組み立て直した (上の付録と同じ)。プラグインと Mason のツールは常用のものを写し、`Lazy! restore` で lock に揃えた (素の状態からの通しを除く)
  - 画面の要る確認は、headless の nvim の `:terminal` (ConPTY) の中の nvim と、Neovide・WezTerm・Windows Terminal の窓の中の nvim を、`--listen` の RPC で操作して読んだ。窓は `PrintWindow` で取り込んで見た
  - 利用者が離席していた間 (最後の入力から 12 分以上) に、窓を前面に出して `SendInput` でキーを打った。キーボードの入力と同じ流れなので IME を通る。打つ前に毎回、前面の窓が検証の窓であることと、利用者の入力が無いことを確かめた。終わった後に前面の窓を戻した
  - zenhan は、ConPTY の確認ではモック、窓の確認では本物 (窓が前面にある間だけ PATH の先頭に置いた。WezTerm は新しいペインの PATH をレジストリから組み立て直すので、WezTerm の中の nvim は初めから本物を使った)
- **取り込みの手順 2** (lock が書き直される場合。#36 の箇条書き): 設定を a82a765 (#29。img-clip.nvim が lock に無い) に戻し、プラグインをその lock の版に揃えた状態から、ブロックをそのまま貼った
  - `Fast-forward` (a82a765 → 3ca878f) の後、起動時に img-clip.nvim が入り、`git status --short` は `M lazy-lock.json` を出した。#35 で更新した 6 個は、古い版のまま lock に書き直されていた
  - 箇条書きのとおり `git checkout -- lazy-lock.json` と `restore` をもう一度貼ると、`git status --short` は空で、38 個 (無効にした render-markdown.nvim 以外) が lock の版に揃った
  - 節のリードの `:Lazy clean` (headless) は markdown-preview.nvim のディレクトリだけを消し、lock は変わらなかった
  - Windows 導入の手順 9 と同じ操作で Mason が tree-sitter-cli を入れて 11 個になった後、手順 10 は `fzf` の WARNING だけだった (写した常用の Mason には tree-sitter-cli が無く、先に流すと `tree-sitter (CLI)` の ERROR が出た)
- **flash の `s`** (#31。ConPTY、21 項目):
  - 手順書の確かめ方: `s` → `nihon` → `;` で「日本語」の「日本」にラベル (`s`) が付き、それで 3 行目の先頭へ飛んだ
  - `atarashii` → `;` → ラベルで「新しい」、`kaizen` → Enter で一番近い「改善」へ飛んだ。`k` → `a` (`a` はラベル) では飛ばずに `ka` で続いた。`function` → `;` → ラベルで英単語へも飛んだ
  - 漢字だけの画面で `k` は辞書に切り替わって 14 件に一致し、終了しなかった。`kai` → `;` → ラベルで「改善案」へ飛んだ
  - 1 打鍵の `flash.state` の `update`: セッションで初めての変換 (辞書の読み込み) が 40.6 ms、2 打鍵目が 12.1 ms、その後は 3 ms 以下。README の画面では最大 29.0 ms (`shi`)、ほかは 1.6〜15.0 ms
  - Neovide 0.16.2 でも、`s` → `nihon` → `;` で「日本」の強調とラベル、最下段の `⚡ nihon;` が描かれ、ラベルで飛んだ。`kaizen` → Enter も同じだった
- **フォーカスが戻ったときの表示** (#37。ConPTY、14 項目):
  - 挿入モードで FocusLost の後に `<C-j>` を押すと、カーソルのすぐ下には出さず、FocusGained で今の状態 (`あ`) を出した。約 1 秒で消えた
  - 外れている間に 3 回切り替えたときは、戻った時点の `A` を出した。変化が無いとき・ノーマルモードでは出さなかった。検索 (`/`) の中でも、戻ったときに検索欄の窓に合わせて出した
  - 端末が送るフォーカスの通知 (`CSI O` / `CSI I`) は、ConPTY を通って FocusLost / FocusGained になり、その通知でも同じように動いた
- **手順 11 の確認項目** (最新の設定。ConPTY、25 項目): `/kensaku`・`<Tab>`・`:w` の整形・`<C-j>` と lualine・カーソルのすぐ下の表示・カーソル色 (`#ff9e64`)・検索欄の右端の `A` / `あ`・検索欄のカーソルのすぐ上の `あ`・検索の sticky・ピッカーのアイコン・終了時の復帰
  - モックの呼び出しは、起動で `get`、挿入モードの `<C-j>` と `<Esc>` で `1,0`、検索で `1,0,1,0` と、操作と 1 対 1 に対応した
- **本物の IME と zenhan** (Neovide 0.16.2 と WezTerm の nightly。IME の状態は、zenhan と同じく窓の IME に問い合わせて読んだ):
  - 始めは IME が閉じていた (変換モード 0x19)。挿入モードで `Ctrl+J` を打つと、Neovim が `あ` になり、本物の zenhan が窓の IME を開いた
  - Neovide: `nihon` と打つと、Neovide がハンドラに未確定文字列 `にほｎ` を渡し、カーソル位置に下線付きで入った (挿入モードのカーソルはその後ろ)。Space で `日本` が変換中の文節 (反転) になり、Enter で行が `日本` になった。extmark は残らなかった
  - WezTerm: 未確定文字列は WezTerm が自分で描き、その間 Neovim のバッファは空のままだった。Enter で `日本` が Neovim に届いた
  - どちらも、IME が開いたまま (未確定文字列なし) の `Ctrl+J` は Neovim に届き、`A` に戻って IME が閉じた。`あ` にしてから `Esc` でノーマルモードに戻ると、`A` になって IME も閉じた
- **SSH 越しのクリップボード** (Windows の端末): ssh の代わりに、この設定の nvim (Windows) を `SSH_CONNECTION` を付けて端末の中で起動した
  - SSH の節の手順 1 の nvim の行は `OSC 52 (copy only)` を出した
  - WezTerm の nightly と Windows Terminal 1.24 のどちらでも、`yy` で Windows のクリップボードが `SSH 越しのヤンクを試す。` と改行 (LF) になった。`p` はすぐに貼り (RPC の往復を含めて 71〜73 ms)、`clipboard` は `unnamedplus`。文字単位の日本語のヤンク (`越しのヤンクを試す。`) も入った
  - クリップボードの中身は始める前に退避し、終わった後に戻した (空だった)。Windows のクリップボードの履歴には試験の文字列が残る
- **SSH 越しのクリップボード (Windows から ssh)**: 上の確認の後、利用者の許可を得て、この PC の WSL の AlmaLinux 10.2 (WSL2、NAT) を接続先にした
  - WSL には Neovim 0.12.5 (公式の Linux 版のリリース) を一時的な場所に置き、この設定 (この PR のブランチ) を一時的な `XDG_CONFIG_HOME` などに入れた。プラグイン 38 個は lock の版に揃え、`git status --short` は空だった
  - sshd は 2 通り: (1) openssh-server 9.9p1-27 の RPM を展開した `sshd` を、自分のユーザーのまま `127.0.0.1:2222` に立てた (`UsePAM no`)。(2) 同じパッケージを dnf で入れ、`/usr/sbin/sshd` を root で `127.0.0.1:2223` に立てた (`UsePAM yes`。検証用の設定ファイルと鍵で、`/etc/ssh` と sshd.service は使っていない)。どちらも Windows の localhost から届いた
  - 手元の端末と ssh: WezTerm の nightly (利用者の設定ファイルのまま) の中の Windows の OpenSSH (`ssh.exe` 9.5p2) と Git for Windows の ssh (OpenSSH 10.3p1)、Windows Terminal 1.24 の中の Windows の OpenSSH。鍵と known_hosts は検証用のもの
  - WezTerm では、ログインしたシェルに検証の準備 (一時的な場所の Neovim と設定を使う 1 行) を打った後、SSH の節の手順 1・2 のブロックを文書から取り出してそのまま貼り (`wezterm cli send-text`。bash には貼り付けとして届く)、Enter を送った。`yy`・`p`・`:set clipboard?` も同じ経路で打った
  - 6 通り (sshd 2 通り × WezTerm の 2 つの ssh と Windows Terminal) のどれでも、手順 1 は `SSH_CONNECTION=127.0.0.1 <ポート> 127.0.0.1 2222` (または 2223) と `OSC 52 (copy only)`、手順 2 の `yy` で Windows のクリップボードが `SSH 越しのヤンクを試す。` と改行 (LF) になった
  - `p` はすぐに貼り (cli の往復を含めて 60〜295 ms)、`:set clipboard?` は noice の窓に `clipboard=unnamedplus` を出した。Windows Terminal では画面を読めないので、nvim を `--listen` 付きで起動して RPC で `yy` と `p` を送り、`clipboard` を読んだ
  - PAM を通す sshd のログインは、`XDG_SESSION_ID` が付き (`c6` など)、loginuid が 1000 の、logind のセッションだった
  - 片付け: 2 つの sshd を止め、openssh-server を外した (入れたときに作られた `sshd` のユーザーとグループも消した)。openssh と openssh-clients は、openssh-server に合わせて 9.9p1-23 から 9.9p1-27 に上がったまま。WSL の一時的な場所と、Windows の検証用の鍵は消した
- **scoop も Git for Windows も PATH に無い状態からの通し** (Windows 導入の手順 1〜11・更新の手順 2・ロールバックの手順 5〜7。ブロックは文書から取り出して Windows PowerShell 5.1 に渡した):
  - scoop は一時的な場所 (`SCOOP`・`XDG_CONFIG_HOME`) に新しく入れた。PATH は Windows の既定の 5 つ (System32 など) とユーザーの PATH (初めは `WindowsApps` だけ) で、ブロックごとに「新しい端末」と同じくレジストリの値から組み立てた
  - scoop が書くユーザーの環境変数 (PATH・`GIT_INSTALL_ROOT`・`C_INCLUDE_PATH` など) と実行ポリシーは、各ブロックの前で `RegOverridePredefKey` を使い、そのプロセスの HKCU を一時的なキーに差し替えて受けた。本物のユーザーの値は変わっていない。scoop がスタートメニューに作った・上書きしたショートカット (Git と 7-Zip) は、退避しておいたものに戻した
  - 手順 1 は何も出さなかった。手順 2 は 6 秒で `Scoop was installed successfully!`。手順 3 は 27 秒で git 2.56.0 (7-Zip も入る) と extras バケット。手順 4 は何も出さず、手順 5 は `custom`
  - 手順 6 は 86 秒で 7 つとも入り、`'neovim' suggests installing 'extras/vcredist2022'` などが出た。手順 7 は `NVIM v0.12.5` と 7 つの場所 (`npm` は `npm.ps1`)
  - 手順 8 の最後の `git status --short` が `M lazy-lock.json` を出した。`git diff` は何も出さず、lock の中身は記録と同じだった
    - scoop の git は `core.autocrlf=true` が既定で (`apps\git\<版>\etc\gitconfig`)、clone が 34 個のファイルを CRLF で取り出していた。lazy.nvim は lock を LF で書き直すので、索引に記録した大きさ (3,770 B) と実物 (3,729 B) が食い違い、git は中身を比べずに変更ありと見なす (`git update-index --refresh` でも消えない)
    - このままだと、取り込みの手順 2 の箇条書き (`checkout` して `restore` をもう一度) も終わらない。`checkout` が CRLF で取り出し直すため
    - `.gitattributes` に `* text=auto eol=lf` を足し (追跡中のファイルはすべて LF なので中身は変わらない)、直した版を同じ git で clone し直すと、36 個とも LF で取り出され、手順 8 は空で 38 個が lock の版に揃った
  - 手順 9 は、開いてから 26 秒で Mason の 11 個、54 秒でパーサーが揃い、ハイライトが効いた。手順 10 は `fzf` の WARNING だけ。手順 11 は上と同じ 25 項目がすべて通った
  - 更新の手順 2: 初回の `scoop update` は main バケットを git のリポジトリに作り直してから `Scoop was updated successfully!` を出し、7 つとも `(latest version)` だった
  - ロールバックの手順 5・6 は何も出さなかった (push していないものも、退避したものも無い)。手順 7 は neovim・zenhan・lazygit だけを消し、ripgrep・fd・gcc・nodejs は残った
  - `nvim.exe` と `lua51.dll` は `VCRUNTIME140.dll` を読み込む (gcc の `objdump -p` で確かめた)。scoop の neovim には同梱されておらず、この PC にはシステムに入っている (14.51)。rg・fd・lazygit・zenhan は読み込まない
- **検証の仕方で起きたこと** (この設定の問題ではない):
  - Neovim も `XDG_CONFIG_HOME` を読むので、scoop の設定を隔離するために付けたままだと、手順 8 が設定を見つけずに `E492: Not an editor command: Lazy! restore` になった。scoop を実行するブロックだけに付けた
  - `RegOverridePredefKey` に渡す `HKEY_CURRENT_USER` は、64 ビットでは符号拡張した値 (`0xFFFFFFFF80000001`) にする。そうしないと `ERROR_INVALID_HANDLE` (6) になる
  - Windows PowerShell 5.1 は、ネイティブコマンドの引数の中の `"` を正しく渡さない。RPC で送る Lua は、ファイルに書いて `dofile` させた
  - Git for Windows の ssh では、ログインした直後のプロンプトに送った 1 文字目が落ちた。空の行を 1 回送ってから打った
  - pwsh からパイプで WSL にファイルを書かせると、最後に CRLF が付く。Windows Terminal の確認で、nvim が `lazyvim-ssh.txt` の後ろに CR の付いた別のファイル (空) を開き、`yy` で改行だけが入った。受け手で CR を消して直した

#### 未確認事項 (2026-09-30 の Windows 11)

- VC++ のランタイムが無い Windows 11 での起動 (この PC ではシステムの `VCRUNTIME140.dll` を外せない)
- 実機の AlmaLinux 10 への、Windows からの ssh と、systemd の sshd.service・既定の `/etc/ssh/sshd_config` でのログイン (WSL の AlmaLinux 10 と検証用の設定で代えた)
- 物理キーボードでの打鍵 (`SendInput` で代えた)
- `.gitattributes` の無い版を CRLF で取り出した clone が、この変更を取り込むときの流れ

### 付録: クリーンインストールした Windows 11 VM での検証記録 (2026-10-06)

- **対象と導入前の状態**:
  - クリーンインストール直後の Windows 11 の複製を、専用の VirtualBox VM `lazyvim-windows11-verify-20261006` にした。導入前の `clean-baseline` snapshot を保存してから試した。終了後は Windows を通常の手順で終了し、導入済みの `verified-lazyvim` snapshot を保存した
  - Windows 11 Enterprise Evaluation、レジストリの `DisplayVersion=26H2`・`CurrentBuild=26300`・`UBR=9457`。Windows PowerShell 5.1.26100.9444 を非管理者として実行した。VirtualBox 7.2.20、メモリ 8 GB、検証を再開した後の CPU は 1 個
  - Guest Additions は入っていた。scoop・git・nvim・rg・fd・gcc・node・npm・zenhan・lazygit はコマンドとして存在せず、通常の設定・データのディレクトリも無かった。`System32` の `VCRUNTIME140.dll`・`MSVCP140.dll` と VC++ ランタイムの登録も無かった
  - この設定は GitHub から通常の `%LOCALAPPDATA%\nvim` に clone した。対象は `custom` の `f0d732d82b41909cee34d5abd481e6591cba6f56`。ホストの設定や変更中の lock は持ち込んでいない
- **実行したこと**:
  - Windows 導入の手順 1〜8・10 の PowerShell ブロックを文書から取り出し、Windows PowerShell 5.1 に渡した。PATH は各実行前に Machine と User の値から読み直した。設定やユーザーのレジストリは隔離せず、この VM の通常の場所に入れた
  - 手順 6 は修正前のブロックで開始し、下記のランタイム不足を再現した後、追加した `scoop install vcredist2022` を別に実行して再開した。修正した手順 1〜11 を頭から再実行した結果ではない
  - HackGen v2.10.0 の公式リリースの NF zip を、公開された SHA256 と照合して展開し、HackGen Console NF の Regular・Bold をユーザーの Fonts とレジストリに登録した。Windows Terminal の既定のフォントを `HackGen Console NF` に設定した
  - 手順 9・11 は Windows Terminal に実際の Neovim を開いて確認した。観測用に `--listen` を付け、実画面の状態を RPC で読んだ。VeryLazy を手動で発火させず、実際の UIEnter から設定が読み込まれた状態を確認した
  - UI のキーは VirtualBox の `keyboardputscancode` で仮想キーボードから送り、Microsoft IME を通した。IME の検証に `nvim_input` や `--remote-send` は使っていない
- **見つけて直したこと**:
  - scoop の neovim 0.12.5 は VC++ ランタイムを同梱せず、`extras/vcredist2022` を suggests として案内するだけだった。修正前の手順 6 の後で `nvim.exe --version` を実行すると、何も出さずに `-1073741515` (`0xC0000135`) で終了した
  - `scoop install vcredist2022` の Microsoft 製インストーラーの x64・x86 の UAC をそれぞれ許可した。14.51.36247 のランタイムが入り、`VCRUNTIME140.dll` は 14.51.36247.0 になった。続く `nvim.exe --version` の出力を最後まで受け取ると、先頭行は `NVIM v0.12.5` で、終了コード 0 だった
  - Windows 導入の手順 6 にランタイムの導入を追加した。PowerShell 自体は非管理者のままでよく、インストーラーには UAC の許可 (標準ユーザーなら管理者の認証) が必要になる
- **確認結果**:
  - scoop の導入、extras の追加、設定の clone、neovim・ripgrep・fd・gcc・nodejs・zenhan・lazygit の導入とコマンド検出が通った。版は neovim 0.12.5、ripgrep 15.2.0、fd 10.5.0、gcc 15.2.0、nodejs 26.10.0、zenhan 0.0.1、lazygit 0.66.0
  - 手順 8 の起動・lock の復元・`Lazy! restore` が終了コード 0 で完了した。Mason の中断と tree-sitter CLI の未導入のメッセージは初回の headless では出たが、実 UI で待つと揃った
  - 有効なリモートプラグイン 38 個の実際の HEAD を lock と照合し、すべて一致した。無効な render-markdown の lock 行は対象外。`core.autocrlf=true` でも `git status --short` は空で、lock に CRLF は無かった
  - 実 UI で Mason の Installed が 11 個、導入中・欠落が 0 個だった。パーサー 30 個のロードと、Markdown の解析が通り、ハイライトが有効だった。marksman は初期化済みで、VeryLazy・ローカルの autocmd・keymap・noice・zenhan の IME 連携が読み込まれていた
  - 手順 10 の health は ERROR が無く、無視してよい `fzf is not installed` の WARNING 1 件だけだった
  - `/kensaku` を実キーで確定すると、本文の「検索」(3 行目のバイト列 12) に移動した。`/kensaku<Tab>` は検索欄を「検索」に置き換えた
  - 挿入モードで `<C-j>` を押すと IME と lualine が「あ」になり、`nihon`・Space・Enter で「日本」を確定できた。Esc でノーマルモードと「A」に戻った。検索でも `<C-j>` が効き、入り直すと日本語の状態を復元して検索欄の右端に「あ」が表示された
  - 実キーの `:w` で `#動作確認` が `# 動作確認` に整形された。別の基礎機能の試験でも、markdownlint の MD018 の検出と修正、整形連鎖が markdownlint-cli2 だけであること、GLFM の `$E = mc^2$` と `[[_TOC_]]` が保たれることを確認した
  - 日本語の表示とステータスラインの Nerd Font のアイコンを画面で確認した。headless の基礎機能の試験では、Migemo の候補の出現回数順と、PowerShell の `system()`・`:read !`・`:grep` の日本語の入出力も通った
- **検証環境と補助処理で起きたこと**:
  - ホストの Hyper-V が有効な NEM 上の 4 CPU の VM で、gcc の導入中に応答が止まった。専用の複製を停止し、1 CPU・nested virtualization 無効で再開した。scoop が Install failed と記録した gcc だけを外し、手順 6・7 を再実行して揃えた。Neovim 設定のエラーは確認されなかった
  - Windows PowerShell 5.1 は BOM の無い UTF-8 の補助 `.ps1` を既定では正しく読まないため、補助処理は UTF-8 を指定して読み込んだ。文書のブロックは UTF-8 の JSON から実行した
  - 手順 7 の `Select-Object -First 1` はネイティブコマンドの出力を途中で閉じるため、表示が正しくても補助処理が終了コード -1 を観測した。起動可否は別に採取した `--version` の全出力と終了コード 0 で判断した
  - RPC の観測クライアントも `--headless` を付けて実行した。仮想キーボードで Shift と文字を一括で送るとコロンの入力が通らないことがあり、Shift の押下・文字・解放を分けて `:w` を確認した

#### 未確認事項 (2026-10-06 の Windows 11 VM)

- 物理キーボードでの打鍵 (OS の IME を通る VirtualBox の仮想キーボードで代えた)
- Neovide と WezTerm、flash の `s`、カーソル直下の短時間の IME 表示、フォーカスが戻ったときの表示
- 今回の VM での更新・取り込み・ロールバックと、GitLab プレビュー・画像貼り付け・SSH の任意の節
- Home / Pro、標準ユーザーが別の管理者の認証を使う UAC (非管理者として動く管理者アカウントの許可で確かめた)

### 付録: 新規 AlmaLinux 10.2 VM での CLI 導入・整形の再検証（2026-10-06）

- **対象と環境**:
  - 公式 ISO から新規導入した AlmaLinux 10.2 Workstation の x86_64 VM（kernel `6.12.0-211.61.1.el10_2.x86_64`、1 CPU、SELinux Enforcing）を使った。一般ユーザーの対話 SSH PTY で、この設定の `custom` / `ae7f049` を公開 URL から通常の `~/.config/nvim` に clone した
  - 共通 bash `3d5323e` と Homebrew 7.0.8 は先に導入した。手順 9 は本文の共通 bash 分岐どおり `. ~/.bashrc` と `brew --version` を使い、直接追記はしなかった
- **導入と確認**:
  - AlmaLinux 導入の手順 1・3〜7・10・11・16〜18 を実行した。EPEL と Homebrew の導入済み分岐を使った。手順 3 の不足分は dnf から入り、Node 22.23.2・npm 10.9.8・gcc 14.3.1、外部コマンドの検出が揃った
  - Neovim 0.12.5（Homebrew formula 0.12.5_1）と lazygit 0.66.0 は bottle で入った。初回 headless の中断通知の後、lock を git から戻して `Lazy! restore` を行った。有効なリモートプラグイン 38 個の実際の HEAD が lock とすべて一致し、修正を転送する前の `git status --short` は空だった
  - 通常 UI で Markdown を開いて待った。`VeryLazy` とローカル autocmd が自然に読み込まれ、Mason は Installed 11・導入中 0、パーサーは 30 個、Markdown highlighting は有効だった。gitcommit のパーサーは最後までコンパイルを待った
  - 手順 18 の health に ERROR / WARNING は無かった（`grep` の終了コードは 1）。手順 19 のうち `/kensaku` は 3 行目の byte 12 に移り、`/kensaku<Tab>` は検索欄を「検索」にした
- **見つけて直したこと**:
  - ツール導入後に起動し直しても `:w` が `#動作確認` を直さず、conform のログに `Formatter 'markdownlint-cli2' timeout` が残った。単独の `markdownlint-cli2 --fix` は正常に直せたが、実行時間は 3.01 秒で、LazyVim の既定の上限 3 秒を超えた
  - `lua/plugins/lang-markdown.lua` を修正し、Markdown / MDX の formatter 連鎖へだけ `timeout_ms=10000` を付けた。名前付きの設定を持つ表の deep-merge で prettier が戻らないよう、`opts` 関数の明示代入で連鎖を置き換えた
  - 修正ファイルを同じ VM に転送して Neovim を起動し直し、通常 UI の `:w` で `# 動作確認` へ直ることを確認した。GLFM の `$E = mc^2$` と `[[_TOC_]]` は保存後も変わらなかった。診断の準備を待ってから打鍵し、RPC を含む完了確認は約 6.8 秒だった
  - 実 UI で Markdown は markdownlint-cli2 だけ、MDX は prettier と markdownlint-cli2、両者の上限は 10000 ms と観測した。既定値は 3000 ms、sh の連鎖は shfmt のままだった。修正 Lua の `stylua --check` も成功した。速い実機での時間は測定していない
- **範囲と補助処理**:
  - 実 UI は通常起動し、観測用に `--listen` を足して状態を RPC で読んだ。`VeryLazy` は手動発火していない。初回通知の `Press ENTER` には Enter を送った
  - 初回 UI からそのまま保存の確認へ進む試験と、lint 診断が来る前の保存は、整形の条件を満たさなかった。本文どおり初回 UI を閉じて再起動し、診断の準備後に確認した
  - CLI の範囲には GNOME の入力ソース・IME の実入力・フォントの見た目・上部バー拡張・GitLab の実サービス・画像貼り付け・SSH のローカルクリップボード・更新・削除を含めない。GNOME での確認は別の VM の記録へ分ける

### 付録: 現行手順を別のクリーン VM の GNOME で再検証 (2026-10-06)

CLI の付録とは別の、新規 AlmaLinux 10.2 / x86_64 Workstation VM で Linux の手順 13〜19 を通した。初期状態は SELinux Enforcing、firewalld 有効、GNOME Shell 49.4、ibus-anthy 1.5.17。共通 bash、Homebrew 7.0.8、Neovim 0.12.5_1、lazygit 0.66.0、HackGen Console NF 2.10.0 と、WezTerm の設定 `4bdfbf1` を導入した。設定は `ae7f049` の clone に、直前の CLI 検証で修正した `lang-markdown.lua` を転送したもの。

- 入力ソースを US と Anthy にし、Anthy の 46 キーを保ったまま `on_off` を `Zenkaku_Hankaku` だけにした。セッションを終えてから新しい GNOME セッションを作った
- 手順 16 の headless 導入・lock の復元後、通常の WezTerm の画面で手順 17 の Markdown を開いた。Mason の 11 ツールとパーサー 30 個が入った。最後の gitcommit はコンパイル完了まで待った。初回の marksman は依存導入中に `MailboxProcessor.PostAndAsyncReply` のタイムアウトで終了したが、導入完了後の起動では再発しなかった
- 手順 18 の health は `fzf` 未導入の WARNING だけで、ERROR は無かった
- 導入完了後に閉じて起動し直し、実キーの `/kensaku` で「検索」の `[1/1]`、Tab で検索入力が「検索」へ変わることを PNG で確認した
- 修正後の実キー `:w` で、ファイルの 1 行目が `# 動作確認` へ直った。GUI でも 10 秒上限の変更が効いた。MDX の実整形はこの GUI 試験では行っていない
- 新しく起動した Neovim で `o` → Ctrl+J を打つと lualine が `A` → `あ`、カーソルが橙になった。Esc で NORMAL と `A` に戻った
- 検索欄は最初 `A`、Ctrl+J で右端が `あ` に変わった。検索欄の近くに一時的な `あ` も写った。Esc で抜けた後の次の `/` は `あ` で始まり、Ctrl+J で `A` に戻せた
- Space 2 回のファイルピッカーとプレビューを開き、HackGen のファイル種別アイコンが豆腐にならないことを確認した。追加した空行は `:qa!` で保存せず閉じた

入力は Mutter の RemoteDesktop を通る実 evdev keycode の押下・解放を使った。`nvim_input` / `--remote-send` による IME 試験はしていない。スクリーンショットと通常 GUI の表示で確認し、`VeryLazy` を手で発火していない。

今回の GUI 試験には、挿入カーソル近くの一時表示の撮影、上部バー追従の拡張、Neovide、物理キーボード、画像貼り付け、SSH / tmux 越しのローカルクリップボード、JIS 配列、Windows / aarch64、設定の更新・削除を含めない。上部バーは拡張を入れていないので英語の表示が残った。通常 GUI と IBus の経路を確認した範囲であり、物理キーの実測とは分ける。

### 付録: Windows 導入の手順 6 の VC++ ランタイムを条件付きにした記録 (2026-10-08)

- **対象**: `custom` の `6c894ee` の作業ツリー (コミット前)。Windows 導入の手順 6 の 1 行目を、`scoop install vcredist2022` から `if (-not (Test-Path -LiteralPath "$env:WINDIR\System32\vcruntime140.dll")) { scoop install vcredist2022 }` に変えた
  - ほかのアプリや winget (`Microsoft.VCRedist.2015+.x64`) でランタイムを入れてある PC で、`vcredist2022` の x64・x86 の UAC を余計に出さないため
- **環境**: x86_64 のクラウドのコンテナ (Linux 6.18)。PowerShell 7.6.6 (公式の Linux 版のリリース `powershell-7.6.6-linux-x64.tar.gz`)。**Windows では何も実行していない**
- **実行したこと**: 手順 6 のブロックを docs/setup.md から取り出し、PowerShell 7.6.6 に渡した
  - `[System.Management.Automation.Language.Parser]::ParseInput` の構文エラーは 0 件、`&&` / `||` のトークンも 0 件だった
  - `scoop` を、引数を記録するだけの関数に替え、`WINDIR` を一時的なディレクトリに向けて、ブロックをそのまま実行した
  - `System32\vcruntime140.dll` が無いときは、`install vcredist2022` と `install neovim ripgrep fd gcc nodejs zenhan lazygit` の 2 回呼んだ
  - 仮のファイル (中身は 1 文字) を `System32\vcruntime140.dll` に置くと、`install neovim ripgrep fd gcc nodejs zenhan lazygit` の 1 回だけ呼んだ
  - Linux の PowerShell は `\` をパスの区切りとして扱った。Windows のファイルシステム (大文字と小文字を区別しない `VCRUNTIME140.dll`、32 ビットのプロセスの `SysWOW64` への読み替え) は、この確認に含まれない

#### 未確認事項 (2026-10-08 の手順 6)

- Windows PowerShell 5.1 での構文と実行 (使っているのは `if`・`-not`・`Test-Path -LiteralPath` と文字列の中の `$env:WINDIR` だけ)
- ランタイムが入っている Windows 11 で、1 行目が何も出さず、UAC も出ないこと
- ランタイムが無い Windows 11 で、これまでどおり x64・x86 の UAC が出て、手順 7 の `nvim --version` が通ること
- winget の `Microsoft.VCRedist.2015+.x64` だけ (x86 なし) で入れた PC で、Neovim が起動すること (`nvim.exe` は x64 なので、x64 のランタイムで足りるはず)
- 古い版のランタイムだけがある PC での Neovim の起動 (1 行目は版を見ない)
- 注意点の、`already installed` と出たときの `scoop uninstall vcredist2022` → `scoop install vcredist2022` の入れ直し。uninstall でランタイムが残ることは、Extras のマニフェスト (`bucket/vcredist2022.json`、2026-10-08 に取得した `14.51.36247.0`) に uninstaller が無く、インストーラーを `post_install` で実行するだけで、`notes` が `You can now remove this installer with 'scoop uninstall vcredist2022'` であることから読んだだけ

## 補足資料に記載していた観測

### dnf で入れるものの観測

- `curl` / `tar` / `gzip` は treesitter と Mason の取得・展開に使う。最小構成のコンテナにも入っていた

### 退避するものの観測

- Neovim を入れる前 (この節の手順 10 より前) に置いたのは、`nvim --version` を 1 回実行しただけで `~/.local/state/nvim` ができるため (コンテナで確認)

### brew の確認の観測

- 依存の無い cask (この節の手順 12) では、確認は出なかった

### フォントと端末の観測

- コンテナでは、`~/.local/share/fonts` に 4 ファイル (`HackGenConsoleNF-{Regular,Bold}.ttf` と `HackGen35ConsoleNF-{Regular,Bold}.ttf`) が入った。`fc-cache` は要らなかった

### 入力ソースを 2 つとも登録する理由の観測

- **`/usr/bin/gsettings` と書く理由**: Homebrew の glib (cairo・ffmpeg・imagemagick・gnupg などの依存で入る) にも `gsettings` があり、`brew shellenv` の後は PATH の先頭に来る。これは dconf を使えず、`~/.config/glib-2.0/settings/keyfile` に黙って書くので、GNOME も Anthy も読まない (AlmaLinux 10 の実機で、この節の手順 13〜15 が効いていなかった)

### Anthy のキーの書き換え方の観測

- コンテナの ibus-anthy 1.5.17 では、既定値は 46 個のキーを持つ dict で、この sed で `on_off` だけが変わり、46 個のまま残った

### <code>lazy-lock.json</code> を戻してから restore する理由の観測

- コンテナでは、1 行目の後に `lazy-lock.json` の 6 個 (nvim-treesitter・nvim-lspconfig・gitsigns.nvim など) が最新の版に書き換わった

### <code>lazy-lock.json</code> を戻してから restore する理由の観測

- 2 行目で記録を git から戻し、3 行目の `restore` でその版にチェックアウトし直す。これで `git status --short` が空になった

### <code>lazy-lock.json</code> を戻してから restore する理由の観測

- `nvim --headless "+Lazy! sync" +qa` は update を含むので、`lazy-lock.json` より新しい版に上げてしまう (コンテナで 6 個が変わった)。揃えるときは使わない

### 初回起動で入るものの観測

- コンテナでは、開いてから 15 秒ほどで揃い、`:Mason` に `Installed (12)` と出た (markdown-toc を外す前の記録。今は 11 個)

### 初回起動で入るものの観測

- 途中で閉じても、次に起動したときに足りないものが入る (コンテナで確認)

