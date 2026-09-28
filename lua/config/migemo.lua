-- ローマ字入力を「ひらがな / カタカナ / 漢字」にもマッチする正規表現へ変換する (Migemo)。
-- エンジンは純 Lua の luamigemo (jsmigemo の移植、辞書同梱、LuaJIT だけで動く)。
-- 配線先は lua/plugins/migemo.lua: `/` `?` の <CR>、flash.nvim の s、snacks picker の grep、
-- 検索コマンドラインの補完 (blink.cmp。ソースは lua/config/migemo_blink.lua)。
-- ノーマルモード / コマンドラインで IME を必ず英数に落とす運用 (lua/config/ime.lua) のため、
-- 「検索のたびに IME を入れ直す」を避ける要になる。
local M = {}

-- 変換対象を「ローマ字として読める入力」に限る判定パターン (Vim 正規表現)。
-- vim-kensaku-search (元は rhysd/migemo-search.vim) の g:kensaku_search#pattern を流用。
--  - 先頭の \v \c などの修飾子 1 個は許容し (\zs で読み飛ばす)、その後ろがローマ字音節
--    (子音の重ね・拗音・「ん」・長音の "-" を含む) の連続で尽きる場合だけ一致する。
--  - search / function のように音節に分解できない英単語、空白・記号・日本語を含む入力は
--    一致せず素通りするので、通常の正規表現検索を壊さない。
--  - menu / banana のように偶然音節になる英単語は変換されるが、Migemo の正規表現は入力
--    そのものも選択肢に含むため取りこぼしは起きない (候補が増えるだけ)。
local ROMAJI =
  [[\c^\%(\\\a\)\=\zs\(\(\(\([bdfghjklmnpstrzwx]\)\4\=\)\=y\=\([ei]\|[aou]h\=\)\)\|\%(ss\=\|dd\=\)\=h[aiuo]\|cc\=h[aio]\|tt\=su\|n\|-\)\+$]]

--- 入力からローマ字部分を取り出す。変換対象でなければ nil。
---@param input string
---@return string|nil word ローマ字部分
---@return integer|nil start ローマ字部分の開始位置 (0 始まりのバイト位置。先頭の修飾子を読み飛ばした後)
function M.romaji(input)
  local found = vim.fn.matchstrpos(input, ROMAJI)
  if found[1] == "" then
    return nil
  end
  return found[1], found[2]
end

--- luamigemo を遅延ロードする。未インストール時は nil (呼び出し側は素通し)。
local function engine()
  local ok, mod = pcall(require, "luamigemo")
  return ok and mod or nil
end

--- 入力を Migemo 正規表現に変換する。
--- 変換対象でない (ローマ字でない)、エンジンが無い、変換に失敗した場合は nil を返し、
--- 呼び出し側は入力をそのまま使う (無ければ何もしない、の流儀は ime.lua と同じ)。
---@param input string 検索入力
---@param flavor "vim"|"rg" 正規表現の方言。vim は Vim の magic 形式、rg は ripgrep 向け (PCRE 風)
---@return string|nil
function M.convert(input, flavor)
  local word = M.romaji(input)
  local mod = word and engine()
  if not mod then
    return nil
  end
  local rxop = flavor == "rg" and mod.RXOP_PCRE or mod.RXOP_VIM
  local ok, pattern = pcall(mod.query, word, rxop)
  if not ok or type(pattern) ~= "string" or pattern == "" then
    return nil
  end
  return pattern
end

-- 候補を集めるバッファの上限 (バイト)。これより大きいバッファでは候補を出さない
-- (本文を丸ごと rg に渡すため、巨大なログなどで毎回の受け渡しが重くなるのを避ける)。
local CANDIDATES_MAX_BYTES = 10 * 1024 * 1024

-- rg に渡す本文のキャッシュ。検索の入力中はバッファが変わらないので、打鍵ごとに作り直さない。
local text_cache = {} ---@type { buf?: integer, tick?: integer, text?: string }

local function buffer_text(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if text_cache.buf ~= buf or text_cache.tick ~= tick then
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    text_cache = { buf = buf, tick = tick, text = text }
  end
  return text_cache.text
end

--- バッファ内で Migemo に一致する文字列を、出現回数の多い順に集める (検索コマンドラインの補完候補)。
--- 照合は ripgrep に任せて非同期で行う。Vim の正規表現は Migemo のような巨大な選択肢の並びに弱く、
--- 数千行のバッファでも打鍵ごとに数百 ms かかる (ka なら 2000 行で 1.5 秒) が、rg なら 3 万行でも
--- 起動込みで 30ms 程度で、一致の数も Vim と変わらない (実測)。本文はファイルではなく標準入力で
--- 渡す: 未保存の変更を含み、cp932 などのファイルも Neovim 内部の UTF-8 で照合できる。
--- 変換対象でない・rg が無い・失敗した場合は空のリストを渡す。入力そのもの (ローマ字の一致) は除く。
---@param input string ローマ字
---@param buf integer バッファ番号 (0 は不可)
---@param on_done fun(list: { text: string, count: integer }[]) メインループで呼ばれる
---@return fun()|nil cancel 実行中の照合を止める関数 (照合を始めなかった場合は nil)
function M.candidates(input, buf, on_done)
  local pattern = M.convert(input, "rg")
  if
    not pattern
    or vim.fn.executable("rg") ~= 1
    or not vim.api.nvim_buf_is_loaded(buf)
    or vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) > CANDIDATES_MAX_BYTES
  then
    on_done({})
    return nil
  end
  local lower = input:lower()
  -- --no-config: 利用者の RIPGREP_CONFIG_PATH (--smart-case や --max-columns など) に出力を左右させない。
  -- --only-matching: 一致した部分だけを 1 行ずつ出す (1 行に複数あればその数だけ)。
  local cmd = { "rg", "--no-config", "--only-matching", "--no-line-number", "--color=never", "--regexp", pattern, "-" }
  local ok, proc = pcall(vim.system, cmd, { stdin = buffer_text(buf), text = true }, function(res)
    local counts, order = {}, {}
    -- 終了コード 1 は「一致なし」、2 はエラー。どちらも候補なしとして扱う。
    if res.code == 0 then
      for text in (res.stdout or ""):gmatch("[^\n]+") do
        if text:lower() ~= lower then
          if not counts[text] then
            counts[text] = 0
            order[#order + 1] = text
          end
          counts[text] = counts[text] + 1
        end
      end
    end
    -- 出現回数の多い順。同数ならバッファ内で先に現れた順 (table.sort は安定でないので明示する)。
    local rank = {}
    for i, text in ipairs(order) do
      rank[text] = i
    end
    table.sort(order, function(a, b)
      if counts[a] ~= counts[b] then
        return counts[a] > counts[b]
      end
      return rank[a] < rank[b]
    end)
    local list = {}
    for _, text in ipairs(order) do
      list[#list + 1] = { text = text, count = counts[text] }
    end
    vim.schedule(function()
      on_done(list)
    end)
  end)
  if not ok then
    on_done({})
    return nil
  end
  return function()
    pcall(proc.kill, proc, 15)
  end
end

return M
