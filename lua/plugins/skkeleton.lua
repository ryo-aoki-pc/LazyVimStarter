local skk_data_dir = vim.fn.stdpath("data") .. "/skk"
local skk_dict_dir = skk_data_dir .. "/dict"

-- skkeleton が直接読めない EUC-JIS-2004 系辞書を iconv で UTF-8 化する
local function convert_dict_to_utf8(name, src_enc)
  local src = skk_dict_dir .. "/" .. name
  local dst = skk_dict_dir .. "/" .. name .. ".utf8"
  if vim.fn.filereadable(src) ~= 1 then
    return
  end
  -- src 側が新しくなったときだけ再変換
  if vim.fn.filereadable(dst) == 1 and vim.fn.getftime(dst) >= vim.fn.getftime(src) then
    return
  end
  vim.notify("Converting " .. name .. " (" .. src_enc .. " -> UTF-8)...", vim.log.levels.INFO)
  local out = vim.fn.system({ "iconv", "-f", src_enc, "-t", "UTF-8", src })
  if vim.v.shell_error ~= 0 then
    vim.notify("iconv failed for " .. name .. " (PATH に iconv が必要):\n" .. out, vim.log.levels.ERROR)
    return
  end
  local f = io.open(dst, "wb")
  if not f then
    vim.notify("Cannot write " .. dst, vim.log.levels.ERROR)
    return
  end
  f:write(out)
  f:close()
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
  -- EUC-JIS-2004 系辞書を UTF-8 へ事前変換 (skkeleton は euc-jp/sjis/utf-8 のみ対応)
  convert_dict_to_utf8("SKK-JISYO.JIS2004", "EUC-JISX0213")
  convert_dict_to_utf8("SKK-JISYO.JIS3_4", "EUC-JISX0213")
  convert_dict_to_utf8("SKK-JISYO.itaiji.JIS3_4", "EUC-JISX0213")
end

return {
  { "vim-denops/denops.vim", lazy = true },
  { "delphinus/skkeleton_indicator.nvim", opts = {} },

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
          vim.fn["skkeleton#config"]({
            globalDictionaries = {
              -- 基本
              skk_dict_dir .. "/SKK-JISYO.L",
              skk_dict_dir .. "/SKK-JISYO.pubdic+",
              -- 固有名詞
              skk_dict_dir .. "/SKK-JISYO.jinmei",
              skk_dict_dir .. "/SKK-JISYO.fullname",
              skk_dict_dir .. "/SKK-JISYO.geo",
              skk_dict_dir .. "/SKK-JISYO.station",
              skk_dict_dir .. "/SKK-JISYO.propernoun",
              -- 連想・補強
              skk_dict_dir .. "/SKK-JISYO.assoc",
              skk_dict_dir .. "/SKK-JISYO.requested",
              skk_dict_dir .. "/SKK-JISYO.notes",
              skk_dict_dir .. "/SKK-JISYO.hukugougo",
              -- 英和
              skk_dict_dir .. "/SKK-JISYO.edict2",
              -- 絵文字 (UTF-8 と明示)
              { skk_dict_dir .. "/SKK-JISYO.emoji", "utf-8" },
              -- 郵便番号 (zipcode サブディレクトリ)
              skk_dict_dir .. "/zipcode/SKK-JISYO.zipcode",
              skk_dict_dir .. "/zipcode/SKK-JISYO.office.zipcode",
              -- 異体字 (EUC-JIS-2004 由来の 3 つは build フックで UTF-8 化済み)
              { skk_dict_dir .. "/SKK-JISYO.JIS2004.utf8", "utf-8" },
              { skk_dict_dir .. "/SKK-JISYO.JIS3_4.utf8", "utf-8" },
              skk_dict_dir .. "/SKK-JISYO.itaiji", -- 純 EUC-JP
              { skk_dict_dir .. "/SKK-JISYO.itaiji.JIS3_4.utf8", "utf-8" },
            },
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
