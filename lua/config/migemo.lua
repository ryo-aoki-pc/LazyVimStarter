-- ローマ字入力を「ひらがな / カタカナ / 漢字」にもマッチする正規表現へ変換する (Migemo)。
-- エンジンは純 Lua の luamigemo (jsmigemo の移植、辞書同梱、LuaJIT だけで動く)。
-- 配線先は lua/plugins/migemo.lua: `/` `?` の <CR>、flash.nvim の s、snacks picker の grep。
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
---@return string|nil
function M.romaji(input)
  local s = vim.fn.matchstr(input, ROMAJI)
  return s ~= "" and s or nil
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

return M
