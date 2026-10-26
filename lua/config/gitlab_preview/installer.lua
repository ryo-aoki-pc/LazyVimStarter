-- 明示的な導入専用。require やプレビューの開始では何も取得しない。
local M = {}
local running = false
local dir = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, "S").source:sub(2)))
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(dir)))

--- @param opts? { wait?: boolean, data_dir?: string, on_done?: fun(ok: boolean) }
function M.run(opts)
  opts = opts or {}
  if running then
    return false, "公式スタイルの導入が進行中"
  end
  if vim.fn.executable("node") == 0 then
    return false, "公式スタイルの導入には Node.js 22 以上が必要"
  end
  running = true
  local done, success, message = false, false, ""
  local command = {
    "node",
    vim.fs.joinpath(root, "tools", "gitlab-preview", "install.mjs"),
    "--data-dir",
    opts.data_dir or vim.fn.stdpath("data"),
  }
  local group = vim.api.nvim_create_augroup("user_gitlab_preview_install", { clear = true })
  local proc
  local ok, err = pcall(function()
    proc = vim.system(command, { text = true }, function(res)
      vim.schedule(function()
        success = res.code == 0
        message = vim.trim(success and (res.stdout or "") or (res.stderr or ""))
        if message == "" then
          message = "導入処理の終了コード: " .. tostring(res.code)
        end
        running, done = false, true
        pcall(vim.api.nvim_del_augroup_by_id, group)
        if not opts.wait then
          vim.notify(message, success and vim.log.levels.INFO or vim.log.levels.ERROR)
        end
        if opts.on_done then
          opts.on_done(success)
        end
      end)
    end)
  end)
  if not ok then
    running = false
    pcall(vim.api.nvim_del_augroup_by_id, group)
    return false, tostring(err)
  end
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      if not done and proc then
        proc:kill(15)
      end
    end,
  })
  if opts.wait then
    local finished = vim.wait(60 * 60 * 1000, function()
      return done
    end, 50)
    if not finished then
      proc:kill(15)
      return false, "公式スタイルの導入を中断した"
    end
    return success, message
  end
  vim.notify("GitLab プレビュー: 公式スタイルを導入中（初回は約785MBを取得する）")
  return true
end

return M
