# 💤 LazyVim 設定 (日本語編集 + Markdown 執筆向け)

[LazyVim](https://github.com/LazyVim/LazyVim) をベースに、日本語の入力・検索と
Markdown (GLFM) 執筆を強化した Neovim 設定。

## 主なカスタマイズ

### 日本語入力・検索

- **[skkeleton](https://github.com/vim-skk/skkeleton)** — SKK 方式の日本語入力 (`<C-j>` でトグル)。
  - 辞書は [skk-dev/dict](https://github.com/skk-dev/dict) をインストール時に自動 clone。
    EUC-JISX0213 の辞書は iconv があれば UTF-8 に自動変換 (なければその辞書のみスキップ)。
  - 変換ソースは `deno_kv` (ローカル辞書の高速キャッシュ) + `google_japanese_input`
    (Google CGI API。読みが HTTP で外部送信される点に注意)。
  - blink.cmp に補完ソースとして統合 (blink.compat + cmp-skkeleton)。
  - 起動 1 秒後にバックグラウンドで事前初期化し、初回 `<C-j>` の待ちをなくす。
- **[vim-kensaku](https://github.com/lambdalisue/vim-kensaku)** — ローマ字のまま日本語をバッファ検索
  (`/kensaku<CR>` が「検索」等にマッチ)。`/` `?` の `<CR>` にのみフック。
- 全角括弧の `%` ジャンプ対応、日本語向け `formatoptions` (mM)、CJK スペルチェック、
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
| [Deno](https://deno.com/) | denops (skkeleton / kensaku の実行基盤) | 日本語入力・検索に必須 |
| git | SKK 辞書の clone | skkeleton の初回 build に必須 |
| iconv | EUC-JISX0213 辞書の UTF-8 変換 | 任意 (なければ該当 4 辞書をスキップ) |
| markdownlint-cli2 / markdown-toc | Markdown の lint・整形 | Mason で自動インストール |
| node | markdown-preview.nvim の build | プレビュー利用時のみ |
| HackGen Console NF | `guifont` に指定 | GUI クライアント利用時のみ |

## lazy-lock.json の運用

プラグインのバージョン再現のため `lazy-lock.json` を git で追跡する。
`:Lazy update` 後に変化した lock ファイルをコミットすること
(別マシンでは `:Lazy restore` で同じバージョンに揃う)。
