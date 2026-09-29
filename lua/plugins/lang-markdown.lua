-- Markdown 言語サポート (LazyVim extra) の設定上書き。
-- extra 本体の有効化は lua/config/lazy.lua の import で行う (import 順序チェックのため
-- extra は lazyvim.plugins の後・plugins の前に置く必要があり、plugins 配下のここでは遅すぎるため)。
-- extra の内容: marksman LSP / markdownlint-cli2 + markdown-toc / conform (整形) /
--       nvim-lint + none-ls (lint 診断) / markdown-preview.nvim / render-markdown.nvim
-- このうち markdown-preview.nvim・render-markdown.nvim・markdown-toc は下で外している。
-- プレビューは GitLab の Markdown API で描く自作のもの (lua/plugins/gitlab-preview.lua)。

-- markdownlint で無効化 (除外) したいルールをここに列挙する。
-- 例:
--   "MD013" 行の長さ制限 / "MD033" インライン HTML / "MD041" 先頭は H1
-- ここでの指定は lint 診断 (nvim-lint) と整形 --fix (conform) の両方に効く。
-- もっと細かい指定 (ルールごとのオプション等) をしたくなったら、下で生成している
-- markdownlint 設定ファイルを直接書く形に切り替えればよい。
local disabled_rules = {
  -- "MD013",
  -- "MD033",
  -- "MD041",
}

local specs = {
  -- ブラウザのプレビュー (markdown-preview.nvim) は外す。2023-10 を最後に更新が止まっており、
  -- node 製のプレビューアプリの build は Windows の 'shell' (PowerShell) では通らない。
  -- 描画は markdown-it で、GLFM 固有の記法 ($`…`$・```math・>>>・アラート・[~] など) を描けない。
  -- 代わりに GitLab 自身に描かせるプレビュー (lua/plugins/gitlab-preview.lua) を <leader>cp に置く。
  -- enabled = false で extra の <leader>cp・:MarkdownPreview* コマンド・build も登録されなくなる。
  { "iamcco/markdown-preview.nvim", enabled = false },

  -- バッファ内インラインレンダリング (render-markdown.nvim) は使わないため無効化する。
  -- 記法をそのまま見て書き (conceal も切っている)、見た目はブラウザのプレビューで確かめる。
  { "MeanderingProgrammer/render-markdown.nvim", enabled = false },

  -- GLFM (GitLab Flavored Markdown) を壊さず整形するため、markdown の整形連鎖から
  -- prettier を除外する。prettier は数式 $...$ の \$ 化・複数行脚注の破壊・[[_TOC_]] の
  -- 再整形などで GLFM 固有構文を壊すため。代わりに GitLab 公式も採用する
  -- markdownlint-cli2 --fix に任せる (リント違反のみ修正し、本文や GLFM 構文は書き換えない)。
  -- markdown-toc も外す。npm の最終リリースが 2017 年で更新が止まっている。GitLab は [[_TOC_]] で
  -- 目次を描画時に作り、ファイルに書き込む目次が要るときは marksman のコードアクション
  -- ("Table of Contents"。見出し ID は GitLab 方式) で作れる。
  -- formatters_by_ft の値はリストなので deep-merge で「置換」され、extra の連鎖を上書きする。
  -- そのため markdown.mdx (JSX 混在。GLFM ではないので prettier は残す) も連鎖を全部書く。
  --
  -- ★ 注意: extras の formatting.prettier を有効にすると、この上書きは無効化される。
  -- あちらは opts 関数の中で formatters_by_ft.markdown に prettier を table.insert するため、
  -- ここでリストを置換しても「置換した後に追記」されて prettier が復活する。
  -- lang.typescript など prettier を推移的に import する extra も同様なので、
  -- 追加する際は markdown の整形連鎖を必ず確認すること。
  --
  -- 一部だけ整形: 整形したい行をビジュアル選択 (V) → <leader>cf。conform が選択範囲を
  -- 自動検出し、markdownlint-cli2 をバッファ全体に適用した上で「選択範囲に重なる差分だけ」反映する
  -- (markdownlint-cli2 は range 非対応だが conform が差分を範囲で絞る。範囲外は不変)。
  -- 注: markdownlint-cli2 はバッファに markdownlint 診断がある時のみ動作 (extra の condition)。
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        markdown = { "markdownlint-cli2" },
        ["markdown.mdx"] = { "prettier", "markdownlint-cli2" },
      },
    },
  },

  -- extra が Mason に入れさせる markdown-toc を外す。LazyVim の mason.nvim の spec は
  -- opts_extend = { "ensure_installed" } なので、テーブルで書くと各 spec のリストが連結されるだけで
  -- 要素を消せない。opts 関数は、それまでの spec を合成した opts を受け取るので、そこから取り除く
  -- (extra は plugins より先に import されるため、この関数は extra の追加より後に走る)。
  -- 既に入っているマシンの markdown-toc は Mason が自動では消さない (:MasonUninstall markdown-toc)。
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(name)
        return name ~= "markdown-toc"
      end, opts.ensure_installed or {})
    end,
  },
}

-- disabled_rules が空の間は以下は丸ごと不要 (設定ファイルを生成せず、lint/整形とも
-- stock の引数のまま動かす)。ルールを追加した時だけ生成と --config の受け渡しを有効化する。
if #disabled_rules > 0 then
  -- disabled_rules から markdownlint 設定 (JSON) を組み立て、cache 配下に書き出す。
  -- markdownlint-cli2 には --config でこのファイルを渡す。--config はあくまで「基準設定」で、
  -- 対象ファイルのあるプロジェクトに .markdownlint(.json/.yaml) 等があればそちらがマージ・
  -- 優先される (プロジェクト個別設定を壊さない)。
  -- ファイル名を *.markdownlint.jsonc にしておくと markdownlint-cli2 が「素の markdownlint
  -- 設定 (ルールをトップレベルに書く形式)」として解釈する。
  local config_path = vim.fn.stdpath("cache") .. "/lazyvim.markdownlint.jsonc"
  local cfg = { default = true } -- 既定は全ルール有効。下で除外分だけ false にする。
  for _, rule in ipairs(disabled_rules) do
    cfg[rule] = false
  end
  local desired = vim.json.encode(cfg)
  -- 内容に変化がある時だけ書き込む (起動毎の無駄な書き込みを避ける)。
  local ok, existing = pcall(function()
    return table.concat(vim.fn.readfile(config_path), "\n")
  end)
  if not ok or existing ~= desired then
    vim.fn.writefile({ desired }, config_path)
  end

  -- lint 診断 (nvim-lint) の markdownlint-cli2 に除外ルール設定を渡す。
  -- この linter の既定 args は { "-" } (stdin 入力)。--config は "-" より前に置く必要があるため、
  -- prepend_args (LazyVim の list_prepend で args の先頭に挿入される) ではなく args を明示的に上書きする。
  table.insert(specs, {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = { "--config", config_path, "-" },
        },
      },
    },
  })

  -- 整形 (--fix) でも lint と同じ除外ルールを使うよう、--config を prepend して渡す
  -- (lint で無効化したルールを整形が勝手に直し返さないよう整合させる)。
  -- 同一プラグインの spec は上の formatters_by_ft と deep-merge される (lazy.nvim の標準動作)。
  table.insert(specs, {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", config_path },
        },
      },
    },
  })
end

return specs
