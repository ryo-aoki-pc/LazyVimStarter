# LazyVimStarter README の検証記録

以下は既存文書から移した記録。本文の「本書」「この文書」と手順番号は、記録元の手順書を指す。新しく検証した記録ではない。
ただし、2026-10-08 の付録 (Windows の lazygit の e) は新しく検証した記録 (Windows では実行していない)。

導入手順は [README](../../README.md) から参照する。

## 実施結果の要約

2026-10-06 に新規 AlmaLinux 10.2 VM で[CLI の導入と整形](setup.md#付録-新規-almalinux-102-vm-での-cli-導入整形の再検証2026-10-06)、別の GNOME VM で[通常 GUI と IBus のキー](setup.md#付録-現行手順を別のクリーン-vm-の-gnome-で再検証-2026-10-06)を再検証した。遅い VM の Markdown 整形の待ち時間も修正して再確認した。物理キーやすべての任意節を一括して確認した記録ではない。

2026-10-08 に、`<leader>gg` の lazygit の `e` のエディタを OS ごとに決める設定 (`lua/plugins/lazygit.lua`。Windows では入れ子の Neovim にし、どちらの OS でも `editInTerminal` を明示する) を Linux で確かめた ([記録](#付録-windows-の-lazygit-の-e-の設定を-linux-で確かめた記録-2026-10-08))。Linux の動きと、Windows の分岐を真似た動きだけで、**Windows の実機では確かめていない**。

## IME 連携の観測

- **Neovim の中では `<C-j>` を使うこと**: gnome-shell は ibus の global engine が外部から
  変わっても自分の内部状態を更新しない (gsettings の `current` を書いても追従しないことを
  実測で確認済み)。そのため nvim がモードに応じてエンジンを切り替えた後に Super+Space を
  押すと、gnome-shell は古い認識を基準に「次のソース」を選ぶので、一手ぶん空振りすることがある
  (もう一度押せば揃う)。`<C-j>` は nvim が直接切り替えるので常に意図どおり動く。
  なお nvim を抜けた時点では上記の復帰処理で必ず整合が取れるため、OS 側の切替が
  壊れたままになることはない。
  GNOME 49 では、[docs/setup.md の上部バーの節](../setup.md#gnome-の上部バーを-ime-連携に合わせる-任意)で
  GNOME Shell の拡張 (`gnome-shell/ibus-engine-follow@ryo-aoki-pc.github.com`) を入れると、上部バーと
  Super+Space の順番が nvim の切り替えに付いてくるので、このずれは起きない。

## 付録: Windows の lazygit の e の設定を Linux で確かめた記録 (2026-10-08)

- **対象**: `custom` の `6c894ee` に `lua/plugins/lazygit.lua` を足した作業ツリー (コミット前)。Windows では snacks.nvim の lazygit の設定に `os.editPreset = "nvim"` と `os.editInTerminal = true` を、Linux では `os.editInTerminal = false` だけを足す
- **環境**: x86_64 のクラウドのコンテナ (Linux 6.18。AlmaLinux ではない)。**Windows では何も実行していない**
  - Neovim 0.12.5 (公式の Linux 版のリリース `nvim-linux-x86_64.tar.gz`)、lazygit 0.66.0 (公式のリリース。`checksums.txt` の SHA256 と一致)、StyLua 2.5.2、tmux 3.4
  - 作業ツリーを `.git` を除いて一時的な `XDG_CONFIG_HOME` に写し、`XDG_DATA_HOME` なども一時的な場所に向けた。AlmaLinux 導入の手順 16 と同じ操作 (`nvim --headless +qa` → lock を戻す → `Lazy! restore`) でプラグイン 38 個を入れ、lock と一致した (snacks.nvim `882c996`、LazyVim `9997009`、lazy.nvim `85c7ff3`)
  - lazygit の設定は、自分用の lazygit の設定 (`ryo-aoki-pc/lazygit` の `custom` の `e6081c2` の `config.yml`。`os.editInTerminal: false` を書いている) を `LG_CONFIG_FILE` で渡した。Linux の動きと Windows の分岐は、`os.editInTerminal: true` に変えた同じ lazygit の設定の作業ツリー (`e6081c2` の上、コミット前) の `config.yml` でも確かめた (以下、`config.yml` の値を false / true と書く)
  - 試験の複製だけ、treesitter のパーサーの取得を止めた (検証環境のプロキシが GitHub の archive を拒み、起動のたびに取得の通知が画面を覆うため)。lazygit の動きには関わらない
  - 画面の要る確認は、tmux の中の本物の画面で nvim を開き、キーを `send-keys` で送り、画面を `capture-pane` で、外側の Neovim の状態を `--remote-expr` で読んだ。開いたのは、変更したファイル (`a.txt`) が 1 つある試験用の git リポジトリ
- **構文と整形**: `stylua --check lua/` (`stylua.toml` のまま) は差分なしで終わった。`nvim -l` で spec のファイルだけを読むと、Linux では snacks.nvim の spec (`lazygit.config.os = { editInTerminal = false }`) を、`has("win32")` を 1 にしたときは (`lazygit.config.os = { editInTerminal = true, editPreset = "nvim" }`) を返した
- **Linux の動き** (spec を足す前と後を比べた):
  - headless で、lazy.nvim が合成した snacks.nvim の `opts.lazygit` は、足す前は `nil`、足した後は `config.os = { editInTerminal = false }` だった。`Snacks.config.lazygit` も同じ (足す前は `{}`)。spec の読み込みの警告 (`spec.notifs`) は前後とも無かった
  - `Snacks.lazygit()` を試験用のリポジトリで開くと、`LG_CONFIG_FILE` は前後とも `<config.yml>,<cache>/nvim/lazygit-theme.yml` だった。snacks が書く `lazygit-theme.yml` の色以外の行は、足す前は `gui.nerdFontsVersion: "3"` と `os.editPreset: "nvim-remote"` だけで、足した後は `os` が `editPreset: "nvim-remote"` と `editInTerminal: false` になった (`config.yml` が false でも true でも同じ)
  - 足した後は、本物の画面で `a.txt` を開いて `<leader>gg` → `e` を打つと、`config.yml` が false でも true でも lazygit の窓が閉じ、外側の Neovim に `a.txt` が出た (窓は 1 つ、ノーマルモード、lazygit の job は 0、lazygit のプロセスも 0。`e` の 1・3・8 秒後とも同じ)
  - 足す前は、`config.yml` が false なら同じく窓が閉じた。true では、外側の Neovim に `a.txt` は開くが、lazygit の浮動ウィンドウが `a.txt` の上に残り (窓は 3 つ)、job も残って、8 秒後も変わらなかった (lazygit のプロセスも残った)
- **Windows の分岐を Linux で真似た確認**: `--cmd` で `vim.fn.has` を包み、`lua/plugins/lazygit.lua` から呼ばれた `has("win32")` だけを 1 にした (ほかの呼び出しは本物のまま)
  - 合成した `opts.lazygit` は `config.os = { editInTerminal = true, editPreset = "nvim" }`、`lazygit-theme.yml` の `os` は `editInTerminal: true` と `editPreset: "nvim"` になった (`config.yml` が false でも true でも同じ)。`LG_CONFIG_FILE` では config.yml の後ろにある
  - 本物の画面で `<leader>gg` → `e` を打つと、lazygit の窓の中に入れ子の Neovim が開いて `a.txt` を出した (外側の Neovim は lazygit の端末のバッファのまま)。`:q` で lazygit に戻り、Command log に `/bin/bash -c "nvim -- "…/a.txt""` が残った。`q` で lazygit を閉じると、外側の `a.txt` に戻った (`config.yml` が false でも true でも同じ)
  - 入れ子の Neovim が `a.txt` を開くと、`W325: Ignoring swapfile from Nvim process <外側の Neovim の pid>` の通知が出た (外側の Neovim が同じファイルを開いているため。Neovim の既定の `nvim.swapfile` の autocmd が、スワップファイルの確認を出さずに開く。`config.yml` は false)
  - 入れ子の Neovim で `i` の後に `<Esc>` を 80ms 空けて 2 回送ると、外側の Neovim がノーマルモード (`mode()` が `n`、バッファは lazygit の端末) になった (snacks の terminal の `term_normal`。200ms 以内の 2 回目の `<Esc>` で `stopinsert`)。外側の lualine も `NORMAL` になり、入れ子の Neovim のプロセスは残っていた。続けて `i` を送ると外側は端末モード (`t`) に戻り、`:q` で入れ子の Neovim が終わって lazygit に戻り、`q` で lazygit が閉じた (`config.yml` は false)
  - 外側の Neovim で `a.txt` を書き換えて保存しないまま `<leader>gg` → `e` を打ち、入れ子の Neovim で書き換えて `:w` → `:q`、lazygit を `q` で閉じると、外側の Neovim に `W12: Warning: File "…/a.txt" has changed and the buffer was changed in Vim as well` の確認が出た (LazyVim は端末が閉じたとき (`TermClose`) に `checktime` する。`config.yml` は false)
  - 比べるため、Windows の分岐から `editInTerminal = true` を消した版 (試験の複製だけ) で、`config.yml` が false のときに同じ操作をすると、`e` を押しても入れ子の Neovim は現れず、lazygit の画面のままだった。lazygit 0.66.0 のソース (`pkg/config/editor_presets.go` の `getEditInTerminal`) は、`editInTerminal` を明示するとプリセットの既定より優先する
  - lazygit が編集のコマンドを Linux の `/bin/bash -c` で実行した結果で、Windows の `cmd.exe /c` は通っていない
- **調べて分かったこと**:
  - lazygit 0.66.0 の `nvim-remote` のコマンドは、シェルが fish・nu でなければ `[ -z "$NVIM" ] && (nvim -- {{filename}}) || (nvim --server "$NVIM" --remote-send "q" && nvim --server "$NVIM" --remote-tab {{filename}})` で、Windows の lazygit のシェルは `cmd` / `/c` (`pkg/commands/oscommands/os_windows.go`)
  - `nvim-remote` のプリセットは、`NVIM` があるとき (Neovim の中) は lazygit を止めない。`editInTerminal` を config.yml で true にすると、それがプリセットの判定より勝ち、`<leader>gg` → `e` で外側の Neovim に `a.txt` は開くが lazygit の窓が残った。spec で `false` を明示した後は、config.yml が true でも false でも窓が閉じた

### 未確認事項 (2026-10-08 の lazygit の e)

- **Windows の実機での `<leader>gg` → `e`** (利用者が確かめる): 変更したファイルがある git のリポジトリのファイルを Windows の nvim で開き、`<leader>gg` → Files の一覧でそのファイルを選んで `e` を押す。lazygit の窓の中に入れ子の Neovim が開き、`:q` で lazygit に戻り、`q` で lazygit が閉じればよい
  - cmd.exe でのファイル名の引用 (空白や日本語を含むパス)、scoop の shim の `nvim` が見つかること
  - WezTerm (既定のシェルは Git Bash) と Windows Terminal (PowerShell) のどちらから起動した nvim でも同じこと
- 入れ子の Neovim の中の IME 連携 (zenhan) と、`:q` で戻った後の外側の lualine の `あ` / `A`
- Windows で `editPreset` を変えないとき (`nvim-remote` のまま) の実際の失敗の見え方 (jesseduffield/lazygit#3467 と、ソースから読んだだけ)
