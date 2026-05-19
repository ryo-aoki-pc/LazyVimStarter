local skk_data_dir = vim.fn.stdpath("data") .. "/skk"
local skk_dict_dir = skk_data_dir .. "/dict"

local function ensure_skk_dict()
  if vim.fn.isdirectory(skk_dict_dir) == 1 then
    return
  end
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
              -- 異体字
              skk_dict_dir .. "/SKK-JISYO.JIS2004",
              skk_dict_dir .. "/SKK-JISYO.JIS3_4",
              skk_dict_dir .. "/SKK-JISYO.itaiji",
              skk_dict_dir .. "/SKK-JISYO.itaiji.JIS3_4",
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
