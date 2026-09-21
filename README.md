# 💤 LazyVim 設定 (日本語編集 + Markdown 執筆向け)

[LazyVim](https://github.com/LazyVim/LazyVim) をベースに、日本語の入力・検索と
Markdown (GLFM) 執筆を強化した Neovim 設定。

## 主なカスタマイズ

### 日本語入力・検索

OS の IME (Linux: ibus/anthy、Windows: zenhan) を Neovim のモードに追従させる。
SKK 方式 (skkeleton) は使わない。実装は `lua/config/ime.lua`。

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
- コマンドライン (`:` `/`) は常に英数。日本語検索は下記の vim-kensaku が担う。
- **終了時は nvim を起動する前の状態に戻す** — gnome-shell は外部からの engine 変更を
  観測しないため、nvim が強制した英数のまま抜けると gnome-shell の内部状態がズレたままになり、
  Super+Space での入力ソース切替が噛み合わなくなる。セッション中に Super+Space で
  切り替えた場合はその値を追随して戻す。`Ctrl+Z` での中断時も同様。
- IME デーモンが居ない環境・headless・対応コマンドが無い Windows では、
  何もせず静かに無効化される (エラーは出ない)。

#### セットアップ (Linux / GNOME + ibus、初回のみ)

```sh
# tmux の中では DBUS_SESSION_BUS_ADDRESS が未設定で gsettings が既定値しか読めないため、
# 必ず明示すること (指定しないと書き込みも黙って効かない)。
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

# 1) 入力ソースに「英語 (US)」を追加する。
#    Neovim は global engine を anthy ↔ xkb:us::eng で切り替えるため、両方が
#    GNOME の入力ソースとして登録されている必要がある (gnome-shell が管理外の
#    エンジンを巻き戻すのを防ぐ)。先頭に置くとログイン直後が英数で始まる。
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'anthy')]"
gsettings get org.gnome.desktop.input-sources sources   # 反映確認

# 2) anthy の on_off ショートカットから Ctrl+J / Ctrl+space を外す。
#    これは anthy *内部* のひらがな⇔Latin モードを切り替えるもので、D-Bus から
#    観測できないため、残したままだと lualine の表示が実際とズレる。加えて
#    Ctrl+J が anthy に食われて Neovim の <C-j> が届かなくなる。
#    ★ anthy の設定は schema 既定とマージされないので、部分的な dict を書くと
#      他のショートカットが全部消える。必ず全体を読んで置換し、確認してから書き戻すこと。
S=org.freedesktop.ibus.engine.anthy.shortcut
v=$(gsettings get $S default \
     | sed "s/'on_off': <\['Zenkaku_Hankaku', 'Ctrl+space', 'Ctrl+J'\]>/'on_off': <['Zenkaku_Hankaku']>/")
printf '%s\n' "$v" | grep -o "'on_off': <\[[^]]*\]>"   # 置換できたか目視してから
gsettings set $S default "$v"
```

置換に失敗する場合は `ibus-setup-anthy` の「キー割り当て」から `on_off` を編集する。
以後の日本語 ON/OFF は **Super+Space** (入力ソース切替) と **Neovim の `<C-j>`** になる。

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
  使いたい場合は `~/.config/tmux/tmux.conf` に以下を足す (無くても無害)。

  ```tmux
  set -ga terminal-overrides ',*:Cs=\E]12;%p1%s\007:Cr=\E]112\007'
  ```

- **Windows**: `zenhan.exe` (推奨) か `im-select.exe` が PATH にあれば同じ挙動になる。
  どちらも無ければ何もしない。
- **[vim-kensaku](https://github.com/lambdalisue/vim-kensaku)** — ローマ字のまま日本語を
  バッファ検索 (`/kensaku<CR>` が「検索」等にマッチ)。`/` `?` の `<CR>` にのみフック。
  検索のたびに IME を入れ直さずに済むので、この構成では要になる。
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

- 有効化済み extras: `lang.markdown` / `lang.json` / `lang.yaml` / `lang.toml` / `editor.dial`
  (`lua/config/lazy.lua` で import。`lazyvim.json` は gitignore のため import 方式で管理)
- Windows では shell を PowerShell (pwsh 優先、UTF-8 入出力) に設定

## 外部依存

| 依存 | 用途 | 必須? |
| --- | --- | --- |
| ibus + ibus-anthy | 日本語入力 (Linux)。Neovim から global engine を切り替える | Linux での日本語入力に必須 |
| busctl / gdbus | ibus との D-Bus 通信。busctl は systemd、gdbus は glib2 に同梱 | どちらか 1 つ (gdbus があれば状態のシグナル購読も有効) |
| [zenhan](https://github.com/iuchim/zenhan) または im-select | 日本語入力 (Windows) | 任意 (無ければ IME 連携のみ無効) |
| [Deno](https://deno.com/) | denops (vim-kensaku の実行基盤) | 日本語検索に必須 |
| markdownlint-cli2 / markdown-toc | Markdown の lint・整形 | Mason で自動インストール |
| node | markdown-preview.nvim の build | プレビュー利用時のみ |
| HackGen Console NF | `guifont` に指定 | GUI クライアント利用時のみ |

## SKK (skkeleton) からの移行

以前は skkeleton による SKK 入力を使っていた。OS の IME に移行したため関連プラグイン
(skkeleton / skkeleton_indicator.nvim / cmp-skkeleton / blink.compat) は削除済み。
`:Lazy clean` でプラグイン本体が消えた後、自動 clone された SKK 辞書 (約 1GB) と
Deno KV キャッシュが残るので、不要なら手で消す。

```sh
rm -rf ~/.local/share/nvim/skk ~/.cache/nvim/skkeleton
```

## lazy-lock.json の運用

プラグインのバージョン再現のため `lazy-lock.json` を git で追跡する。
`:Lazy update` 後に変化した lock ファイルをコミットすること
(別マシンでは `:Lazy restore` で同じバージョンに揃う)。
