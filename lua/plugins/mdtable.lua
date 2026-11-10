-- Windows だけで、カーソルのある表を mdtable で Excel に開く。
if vim.fn.has("win32") ~= 1 then
  return {}
end

return {
  {
    -- virtual spec で取得や lock への追加をせず、初めて使うまで実体を読み込まない。
    "mdtable-edit",
    virtual = true,
    cmd = { "MdTableEdit" },
    keys = {
      { "<leader>te", "<cmd>MdTableEdit<cr>", ft = "markdown", desc = "表を Excel で編集 (mdtable)" },
    },
    config = function()
      vim.api.nvim_create_user_command("MdTableEdit", function()
        require("config.mdtable").edit()
      end, { desc = "表を Excel で編集 (mdtable)" })
    end,
  },
}
