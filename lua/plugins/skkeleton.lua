local skk_data_dir = vim.fn.stdpath("data") .. "/skk"
local skk_dict_dir = skk_data_dir .. "/dict"

-- 補完候補の表示順を保存するファイル (data 配下: 学習した順位はセッション間で残したいため).
local skk_completion_rank = skk_data_dir .. "/completion-rank.json"
-- 辞書解析結果の Deno KV キャッシュ (cache 配下: 辞書から再生成可能。2 回目以降の初回 <C-j> を高速化).
local skk_database_dir = vim.fn.stdpath("cache") .. "/skkeleton"
local skk_database_path = skk_database_dir .. "/dict-cache.db"

-- 登録対象辞書 (相対パス). 順序は変換候補の優先順.
local dict_names = {
  "SKK-JISYO.L",
  "SKK-JISYO.pubdic+",
  "SKK-JISYO.jinmei",
  "SKK-JISYO.fullname",
  "SKK-JISYO.geo",
  "SKK-JISYO.station",
  "SKK-JISYO.propernoun",
  "SKK-JISYO.assoc",
  "SKK-JISYO.requested",
  "SKK-JISYO.notes",
  "SKK-JISYO.hukugougo",
  "SKK-JISYO.edict2",
  "SKK-JISYO.emoji",
  "zipcode/SKK-JISYO.zipcode",
  "zipcode/SKK-JISYO.office.zipcode",
  "SKK-JISYO.JIS2004",
  "SKK-JISYO.JIS3_4",
  "SKK-JISYO.itaiji",
  "SKK-JISYO.itaiji.JIS3_4",
}

-- 辞書ファイル先頭の `;; -*- ... coding: <enc> ... -*-` 宣言を取得
local function read_coding(path)
  if vim.fn.filereadable(path) ~= 1 then
    return ""
  end
  local first = (vim.fn.readfile(path, "", 1)[1] or ""):lower()
  return first:match("coding:%s*([%w%-_]+)") or ""
end

-- 1 辞書を「skkeleton に渡せる形」(path 単体または {path, enc} タプル) に解決し,
-- 必要なら iconv で .utf8 を生成する (副作用).
-- - coding が utf-8/euc-jp の場合: パス文字列を返す (skkeleton 自動判定)
-- - coding が euc-jis-2004 / euc-jisx0213 の場合: 同名 + ".utf8" を作って {path, "utf-8"} を返す
-- - 宣言が読めない場合: パス文字列を返す (自動判定にフォールバック)
local function resolve_dict(rel_path)
  local src = skk_dict_dir .. "/" .. rel_path
  local coding = read_coding(src)
  if coding:match("euc%-jis%-2004") or coding:match("euc%-jisx0213") then
    local dst = src .. ".utf8"
    if
      vim.fn.filereadable(src) == 1
      and (vim.fn.filereadable(dst) ~= 1 or vim.fn.getftime(dst) < vim.fn.getftime(src))
    then
      vim.notify("Converting " .. rel_path .. " (" .. coding .. " -> UTF-8)...", vim.log.levels.INFO)
      local out = vim.fn.system({ "iconv", "-f", "EUC-JISX0213", "-t", "UTF-8", src })
      if vim.v.shell_error ~= 0 then
        vim.notify("iconv failed for " .. rel_path .. ":\n" .. out, vim.log.levels.ERROR)
      else
        local f = io.open(dst, "wb")
        if f then
          f:write(out)
          f:close()
        end
      end
    end
    return { dst, "utf-8" }
  end
  -- それ以外 (euc-jp / utf-8 / 不明) は skkeleton の自動判定に任せる
  return src
end

local function ensure_skk_dict()
  if vim.fn.isdirectory(skk_dict_dir) ~= 1 then
    vim.fn.mkdir(skk_data_dir, "p")
    vim.notify("Cloning SKK-JISYO dictionaries (skk-dev/dict)...", vim.log.levels.INFO)
    local out = vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/skk-dev/dict.git",
      skk_dict_dir,
    })
    if vim.v.shell_error ~= 0 then
      vim.notify("SKK dict clone failed:\n" .. out, vim.log.levels.ERROR)
      return
    end
  end
  -- 全辞書をスキャンして coding 宣言を読み, 必要なものだけ変換 (resolve_dict が副作用で行う)
  for _, name in ipairs(dict_names) do
    resolve_dict(name)
  end
end

return {
  -- SKK スタック (denops / skkeleton / cmp-skkeleton / indicator)。lazy.lua の defaults.lazy=false の
  -- ため、各プラグインに lazy=true を明示しないと起動時にロードされる。blink.cmp(InsertEnter) の依存に
  -- cmp-skkeleton を置くと「最初の挿入で denops(Deno) コールドスタート + 19 辞書ロード」の同期待ちが
  -- 走り挿入モードが固まるため、その依存連鎖は断ったまま SKK 一式を skkeleton の dependencies へ寄せる。
  --
  -- ロード契機は 2 つ:
  --  1) <C-j> (keys): SKK を使う正規の発火条件。
  --  2) 起動後のバックグラウンド事前ウォームアップ (skkeleton の init 内 autocmd):
  --     PC 起動直後 (コールドキャッシュ) の初回 <C-j> で Deno 起動 + 辞書ロードを同期で
  --     待たされる問題への対策。重い処理は別プロセス (Deno) で非同期に進むため UI は
  --     ブロックせず、InsertEnter とも無関係なので挿入モードの固まりは再発しない。
  { "vim-denops/denops.vim", lazy = true },
  { "saghen/blink.compat", version = "2.*", lazy = true, opts = {} },
  -- cmp-skkeleton は require('cmp') で blink.compat の cmp シムにソース登録するため compat に依存させる。
  { "uga-rosa/cmp-skkeleton", lazy = true, dependencies = { "saghen/blink.compat" } },
  -- インジケータは VeryLazy でロードする。インジケータ本体は「ロード後最初の InsertEnter」で
  -- 実体化される設計 (グループなしの once autocmd) のため、skkeleton 経由 (事前ウォームアップ =
  -- VeryLazy+1 秒/<C-j>) のロードだけだと、それより早い初回 InsertEnter で表示されない
  -- (イベントは遡って発火せず、lazy.nvim の event 再発火もグループ付き autocmd しか対象にしない)。
  -- VeryLazy はユーザー入力より前に発火するため、これで初回挿入から表示される。
  -- インジケータは denops 非依存の純 Lua であり、VeryLazy での同期ロードは軽量 (数 ms)。
  { "delphinus/skkeleton_indicator.nvim", lazy = true, event = "VeryLazy", opts = {} },

  {
    "vim-skk/skkeleton",
    -- <C-j> で skkeleton を起動した時に、依存 (denops / cmp ソース / indicator) をまとめて読み込む。
    dependencies = {
      "vim-denops/denops.vim",
      "uga-rosa/cmp-skkeleton",
      "delphinus/skkeleton_indicator.nvim",
    },
    build = ensure_skk_dict,
    keys = {
      { "<C-j>", "<Plug>(skkeleton-toggle)", mode = { "i", "c", "t" }, desc = "Toggle SKK" },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "skkeleton-initialize-pre",
        callback = function()
          -- resolve_dict は副作用 (.utf8 生成) を伴うが冪等. coding 宣言を見て
          -- 必要なら iconv で UTF-8 化し, skkeleton に渡せる形 (string or {path, enc}) を返す.
          local dicts = {}
          for _, name in ipairs(dict_names) do
            table.insert(dicts, resolve_dict(name))
          end
          -- completionRankFile / databasePath の親ディレクトリを保証する。
          -- skkeleton (Deno KV) はファイルは作るが親ディレクトリは作らないため。mkdir -p は冪等。
          vim.fn.mkdir(skk_data_dir, "p")
          vim.fn.mkdir(skk_database_dir, "p")
          vim.fn["skkeleton#config"]({
            globalDictionaries = dicts,
            eggLikeNewline = true,
            registerConvertResult = true,
            -- 補完候補の表示順をファイルに保存して永続化する (未設定だと毎セッション初期化される).
            completionRankFile = skk_completion_rank,
            -- 辞書を Deno KV でDB化し、2 回目以降の起動 (初回 <C-j>) の辞書ロードを高速化する.
            databasePath = skk_database_path,
          })
        end,
      })

      -- PC 起動後の初回 <C-j> で「Deno コールドスタート + 辞書ロード」を同期で待たされる問題への対策:
      -- 起動後のアイドル時にバックグラウンドで SKK スタックを事前初期化する。これにより <C-j> 時点では
      -- denops + 辞書がロード済みになり、toggle 内部の同期待ち (denops#plugin#wait) が即座に返る。
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          -- headless (nvim --headless "+Lazy! sync" 等) では SKK を使わないため、
          -- プラグインのソース読込ごとスキップする。
          if #vim.api.nvim_list_uis() == 0 then
            return
          end
          -- LazyVim 自身の VeryLazy 処理や PC 起動直後のディスク競合を避けて少し遅らせる。
          -- 重い処理 (Deno 起動・辞書ロード) は別プロセスで非同期に進むため UI はブロックしない。
          vim.defer_fn(function()
            pcall(function()
              -- SKK 一式 (denops / cmp ソース / indicator) をロードする (同期だが数十 ms 程度)。
              -- lazy.nvim の load() はプラグインの短縮名 ("skkeleton") で引く。
              require("lazy").load({ plugins = { "skkeleton" } })
              -- skkeleton#initialize は notify_async ベースで一切ブロックしない。denops 未起動でも
              -- queue されるため直後に呼んで安全。失敗しても <C-j> の通常経路がフォールバックになる。
              vim.fn["skkeleton#initialize"]()
            end)
          end, 1000)
        end,
      })
    end,
  },

  {
    "saghen/blink.cmp",
    -- 依存は blink.compat のみ (cmp-skkeleton を外す)。これで InsertEnter で blink が読まれても
    -- denops/skkeleton は起動しない。skkeleton ソース定義は残し、enabled で動的に有効化する。
    dependencies = { "saghen/blink.compat" },
    opts = {
      sources = {
        default = { "skkeleton", "lsp", "path", "snippets", "buffer" },
        providers = {
          skkeleton = {
            name = "skkeleton",
            module = "blink.compat.source",
            score_offset = 100,
            -- skkeleton 未ロード時 (事前ウォームアップ前/失敗時) に skkeleton#is_enabled() を呼ぶと
            -- E117 になるため pcall でガード。ロード済みでも SKK 未起動なら false = ソース無効。
            -- <C-j> で skkeleton が有効化されると true を返す。
            enabled = function()
              local ok, on = pcall(function()
                return vim.fn["skkeleton#is_enabled"]() == 1
              end)
              return ok and on
            end,
          },
        },
      },
    },
  },
}
