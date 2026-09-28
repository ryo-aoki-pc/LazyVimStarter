-- blink.cmp の補完ソース: 検索コマンドライン (/ ?) で、打ったローマ字に Migemo で一致する
-- バッファ内の文字列 (検索 / けんさく / ケンサク …) を候補に出す。選ぶとローマ字がその文字列に
-- 置き換わり、<CR> でその文字列そのもの (リテラル) を検索する。IME を使わずに日本語を打つ手段で、
-- 探す文字列は必ずバッファにあるので変換辞書も要らない。Migemo の正規表現で探すより絞り込める。
-- 配線は lua/plugins/migemo.lua (blink の cmdline.sources に追加)。照合は config.migemo.candidates。
-- lua/plugins/ の下に置くと lazy.nvim が spec として import してしまうため、ここに置く。
local migemo = require("config.migemo")

-- 候補を出す最短のローマ字 (バイト数)。短いと Migemo の正規表現が巨大になり、変換だけで
-- 打鍵が引っかかる (ka で 30ms 超) うえ、候補も多すぎて選べない。
local MIN_LENGTH = 3
-- 候補の上限。出現回数の多い順に切る。
local MAX_ITEMS = 50

local Source = {}
Source.__index = Source

function Source.new()
  return setmetatable({}, Source)
end

local function search_cmdtype()
  local cmdtype = vim.fn.getcmdtype()
  return (cmdtype == "/" or cmdtype == "?") and cmdtype or nil
end

-- 検索コマンドラインの中だけで働く。q/ のコマンドラインウィンドウでは getcmdtype() が空なので対象外。
function Source:enabled()
  return search_cmdtype() ~= nil
end

function Source:get_completions(ctx, callback)
  local function respond(items)
    -- 打鍵ごとに取り直させる (ローマ字が変われば一致も変わる)。backward も true にしないと、
    -- <BS> で戻したときに消す前の入力で集めた候補が残る。
    callback({ items = items, is_incomplete_forward = true, is_incomplete_backward = true })
  end
  local cmdtype = search_cmdtype()
  local word, start = migemo.romaji(ctx.line:sub(1, ctx.cursor[2]))
  if not cmdtype or not word or #word < MIN_LENGTH then
    return respond({})
  end
  -- blink は受け取った候補を、カーソル直前のキーワード (/ の後の英数字の並び) で絞り込む。
  -- 日本語のラベルはローマ字とは一致しないので、絞り込み用の文字列をそのキーワード自体にする。
  local keyword = ctx.line:sub(ctx.bounds.start_col, ctx.cursor[2])
  local kind = require("blink.cmp.types").CompletionItemKind.Text
  local cancelled = false
  local cancel = migemo.candidates(word, ctx.bufnr, function(list)
    if cancelled then
      return
    end
    local items = {}
    for i, candidate in ipairs(list) do
      if i > MAX_ITEMS then
        break
      end
      items[i] = {
        label = candidate.text,
        filterText = keyword,
        sortText = string.format("%04d", i),
        kind = kind,
        labelDetails = { description = candidate.count .. "件" },
        textEdit = {
          -- 置き換えるのはローマ字の部分だけ (先頭の \c などの修飾子は残す)。選んだ文字列を
          -- リテラルとして検索させるため、magic で特別な意味を持つ文字と、この検索の区切り文字を
          -- 逃がす。区切りは / か ? の一方だけにする (/ 検索で ? を逃がすと \? = 0 回か 1 回になる)。
          newText = vim.fn.escape(candidate.text, [[\.*$^~[]] .. cmdtype),
          range = {
            start = { line = 0, character = start },
            ["end"] = { line = 0, character = ctx.cursor[2] },
          },
        },
      }
    end
    respond(items)
  end)
  return function()
    cancelled = true
    if cancel then
      cancel()
    end
  end
end

return Source
