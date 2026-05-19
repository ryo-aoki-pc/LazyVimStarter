local skk_data_dir = vim.fn.stdpath("data") .. "/skk"
local skk_dict_dir = skk_data_dir .. "/dict"

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
  { "vim-denops/denops.vim", lazy = true },

  {
    "vim-skk/skkeleton",
    dependencies = { "vim-denops/denops.vim" },
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
          vim.fn["skkeleton#config"]({
            globalDictionaries = dicts,
            eggLikeNewline = true,
            registerConvertResult = true,
          })
        end,
      })
    end,
  },

  { "saghen/blink.compat", version = "2.*", lazy = true, opts = {} },

  {
    "uga-rosa/cmp-skkeleton",
    dependencies = { "vim-skk/skkeleton" },
  },

  {
    "saghen/blink.cmp",
    dependencies = { "uga-rosa/cmp-skkeleton", "saghen/blink.compat" },
    opts = {
      sources = {
        default = { "skkeleton", "lsp", "path", "snippets", "buffer" },
        providers = {
          skkeleton = {
            name = "skkeleton",
            module = "blink.compat.source",
            score_offset = 100,
            enabled = function()
              return vim.fn["skkeleton#is_enabled"]() == 1
            end,
          },
        },
      },
    },
  },
}
