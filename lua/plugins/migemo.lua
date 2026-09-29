-- ローマ字のまま日本語を検索する (Migemo)。変換器の実体は lua/config/migemo.lua。
-- 例: /kensaku<CR> が「検索」「けんさく」「ケンサク」等にマッチ。同じ変換を flash の s と
-- snacks picker の grep にも配線しているので、バッファ内ジャンプもプロジェクト grep も
-- IME を入れずに済む。/kensaku<Tab> なら一致した文字列そのものを補完候補から選べる (blink.cmp)。
-- 以前は vim-kensaku (denops) を使っていたが、Deno という外部ランタイム・初回の辞書
-- ダウンロード・起動直後は denops 未起動で検索が失敗する、という 3 つの面倒があった。
-- luamigemo は同じ jsmigemo の純 Lua 移植で辞書も同梱しているため、いずれも無くなる。
local migemo = require("config.migemo")

-- 決して一致しないパターン (0 行目)。flash に渡す skip パターンなどに使う。
local NEVER = "\\%0l"

-- 今のタブの画面に見えている範囲に、pattern の一致があるか (flash の s が探すのと同じ範囲)。
-- 各ウィンドウの表示先頭から最初の一致まで探すだけなので、一致があれば軽い。
local function visible_match(pattern)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local found = vim.api.nvim_win_call(win, function()
        local view = vim.fn.winsaveview()
        vim.api.nvim_win_set_cursor(0, { vim.fn.line("w0"), 0 })
        local ok, lnum = pcall(vim.fn.search, pattern, "cnW", vim.fn.line("w$"))
        vim.fn.winrestview(view)
        return ok and lnum > 0
      end)
      if found then
        return true
      end
    end
  end
  return false
end

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
  -- 操作は s → ローマ字 → ; → ラベル (Enter なら一番近い一致へ)。
  -- LazyVim 既定の s を同じ lhs/mode で上書き (後から読まれる spec の keys が勝つ)。
  -- search.mode に関数を渡すと、入力文字列ごとに検索パターンを組み立てられる
  -- (flash/search/pattern.lua)。1 文字ごとに照合し直すので、打ちかけのローマ字 (nihon の途中の nih)
  -- も変換する convert_incremental を使う (重い入力はまずかなだけで探し、画面に無ければ辞書を引く)。
  -- 読めない入力は flash 既定の exact と同じ \V リテラルにする。
  --  - trigger = ";": ラベルは ; を打った後でしか効かない (flash の check_jump)。flash は本来、
  --    一致の直後にある文字をラベルから外して打ち足しとの衝突を防ぐが、日本語の一致の直後は日本語
  --    なので a や e がラベルに残り、kensaku を打つ途中で飛んでしまう。; は入力の末尾から除いてから
  --    mode に渡される (flash/search/pattern.lua の set)。
  --  - 2 つ目の戻り値 (ラベルを外すための skip パターン) は、決して一致しない NEVER にする。; があれば
  --    外す必要が無く、Migemo の正規表現でバッファ全体を探し直す既定の処理は 1000 行で 0.4〜1.6 秒
  --    かかる (実測)。
  --  - 一度一致が出た後は、画面から一致が無くなる打鍵では直前の一致を保つ。flash は一致が 0 件に
  --    なると終了し、続けて打った ; やラベルがノーマルモードのコマンドとして実行されてしまう
  --    (a なら挿入モードに入る)。同梱辞書には送り仮名まで含めた語が無いことが多く
  --    (atarashi は 新し に一致するが atarashii は 新しい に一致しない)、読みを最後まで打つと起きる。
  {
    "folke/flash.nvim",
    optional = true,
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          local last -- この s の間に、最後に画面で一致したパターン
          require("flash").jump({
            search = {
              trigger = ";",
              mode = function(input)
                -- s の直後に ; だけを打った場合 (空のパターンは全位置に一致してしまう)
                if input == "" then
                  return NEVER, NEVER
                end
                local pattern, broader = migemo.convert_incremental(input)
                pattern = pattern or ("\\V" .. input:gsub("\\", "\\\\"))
                -- かなだけの軽いパターンで画面に一致が無ければ、辞書を引いた広いパターンに替える
                if broader and not visible_match(pattern) then
                  pattern = broader() or pattern
                end
                if last and not visible_match(pattern) then
                  return last, NEVER
                end
                last = pattern
                return pattern, NEVER
              end,
            },
          })
        end,
        desc = "Flash (Migemo、; の後でラベル)",
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

  -- 検索コマンドライン (/ ?) の補完に Migemo の一致を足す。/kensaku の後に <Tab> で、バッファ内に
  -- 実在する「検索」「けんさく」などを出現回数の多い順に選べ、選ぶとその文字列そのものを検索する
  -- (Migemo の正規表現で探すより絞り込める)。<Tab> を押さずに <CR> なら上の <CR> で従来どおり
  -- Migemo の検索になる。blink は cmdline の <CR> をマップしないので、上の <CR> とは競合しない。
  -- ソースの実体は lua/config/migemo_blink.lua。
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.migemo = {
        name = "Migemo",
        module = "config.migemo_blink",
        -- buffer ソース (-3) の単語より上に並べる
        score_offset = 100,
      }
      -- cmdline のソース一覧は spec 間でマージされず丸ごと置き換わるため、blink の既定
      -- { "buffer", "cmdline" } (どちらも自分の対象外のコマンドラインでは無効になる) ごと書く。
      opts.cmdline = opts.cmdline or {}
      opts.cmdline.sources = { "migemo", "buffer", "cmdline" }
    end,
  },
}
