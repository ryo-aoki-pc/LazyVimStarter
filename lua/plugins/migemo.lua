-- ローマ字のまま日本語を検索する (Migemo)。変換器の実体は lua/config/migemo.lua。
-- 例: /kensaku<CR> が「検索」「けんさく」「ケンサク」等にマッチ。同じ変換を flash の s と
-- snacks picker の grep にも配線しているので、バッファ内ジャンプもプロジェクト grep も
-- IME を入れずに済む。
-- 以前は vim-kensaku (denops) を使っていたが、Deno という外部ランタイム・初回の辞書
-- ダウンロード・起動直後は denops 未起動で検索が失敗する、という 3 つの面倒があった。
-- luamigemo は同じ jsmigemo の純 Lua 移植で辞書も同梱しているため、いずれも無くなる。
local migemo = require("config.migemo")

return {
  {
    "delphinus/luamigemo",
    -- 同梱辞書と Lua モジュールだけの plugin/ を持たないライブラリ。version = "*" でタグに追随し、
    -- lazy-lock.json で固定する (LazyVim 既定の version = false を上書き)。
    version = "*",
    event = "VeryLazy",
    -- 検索コマンドライン (/ ?) の <CR> で、入力がローマ字なら Migemo の正規表現に置換してから
    -- 検索を実行する。getcmdtype() でガードし、: 等の非検索コマンドラインでは素の <CR> に
    -- フォールバックする。ローマ字でない入力 (英単語・正規表現・日本語) は触らない。
    -- 注: remap=true を付けないこと。expr の戻り値 <CR> がこのマッピング自身に再入して再帰する。
    -- expr の Lua コールバックは replace_keycodes が既定で有効なため追加オプション不要。
    keys = {
      {
        "<CR>",
        function()
          local cmdtype = vim.fn.getcmdtype()
          if cmdtype == "/" or cmdtype == "?" then
            local pattern = migemo.convert(vim.fn.getcmdline(), "vim")
            if pattern then
              vim.fn.setcmdline(pattern)
            end
          end
          return "<CR>"
        end,
        mode = "c",
        expr = true,
        silent = true,
        desc = "Migemo 検索",
      },
    },
  },

  -- flash.nvim の s (ラベルジャンプ) でもローマ字で日本語に飛べるようにする。
  -- LazyVim 既定の s を同じ lhs/mode で上書き (後から読まれる spec の keys が勝つ)。
  -- search.mode に関数を渡すと、入力文字列ごとに検索パターンを組み立てられる
  -- (flash/search/pattern.lua)。ローマ字でない入力は flash 既定の exact と同じ \V リテラルにする。
  -- 既知の癖: ローマ字を打ち足す途中でラベル文字と衝突すると即ジャンプすることがある。
  -- 気になるようなら label.exclude に衝突しやすい文字を足す。
  {
    "folke/flash.nvim",
    optional = true,
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump({
            search = {
              mode = function(input)
                return migemo.convert(input, "vim") or ("\\V" .. input:gsub("\\", "\\\\"))
              end,
            },
          })
        end,
        desc = "Flash (Migemo)",
      },
    },
  },

  -- snacks picker の grep (<leader>/ <leader>sg <leader>sG <leader>sB) でもローマ字で日本語を探す。
  -- 入力の検索パターン部分だけを ripgrep 向けの Migemo 正規表現に差し替えて、標準の grep finder に
  -- 委譲する。"foo -- -g *.md" 形式の追加引数 (Snacks.picker.util.parse) はそのまま通す。
  -- ctx.filter.search はコマンド組み立て (get_cmd) が finder 呼び出し中に同期で走るので、
  -- 差し替え→委譲→復元で副作用を残さない。grep_word (<leader>sw, regex=false) は対象外。
  {
    "folke/snacks.nvim",
    optional = true,
    opts = function(_, opts)
      local function grep(source_opts, ctx)
        local grep_source = require("snacks.picker.source.grep")
        local search = ctx.filter.search
        local pattern = Snacks.picker.util.parse(search)
        local converted = migemo.convert(pattern, "rg")
        if not converted then
          return grep_source.grep(source_opts, ctx)
        end
        -- parse と同じ区切り (空白 + "--") で追加引数を保存し、パターン部分だけ入れ替える
        local extra = search:match("^.-(%s+%-%-.*)$") or ""
        ctx.filter.search = converted .. extra
        local ok, finder = pcall(grep_source.grep, source_opts, ctx)
        ctx.filter.search = search
        if not ok then
          error(finder)
        end
        return finder
      end
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.grep = vim.tbl_extend("force", opts.picker.sources.grep or {}, { finder = grep })
      opts.picker.sources.grep_buffers =
        vim.tbl_extend("force", opts.picker.sources.grep_buffers or {}, { finder = grep })
    end,
  },
}
