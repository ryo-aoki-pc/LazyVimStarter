-- 通常設定や実 GitLab の認証を使わず、描画と導入成功後のページ交換を通して確かめる。
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)
local assets = require("config.gitlab_preview.assets")
local installed = nil
assets.load = function()
  return installed
end
package.loaded["config.gitlab_preview.gitlab"] = {
  context = function()
    return { root = root, api = { origin = "https://fixture.invalid", host = "fixture.invalid", path = "" } }
  end,
  relpath = function()
    return ""
  end,
  render = function(_, _, callback)
    vim.schedule(function()
      callback({ kind = "ok", html = '<h1 data-sourcepos="1:1-1:5">Fixture</h1>' })
    end)
    return function() end
  end,
}
-- vim.env の参照先だけを試験用の表に替える。OS 側の秘密情報を読み書きしない。
local original_env = vim.env
vim.env = { GITLAB_TOKEN = "fixture-not-a-secret" }
vim.g.gitlab_preview_browser = function() end
vim.g.gitlab_preview_appearance = { theme = "dark", width = "fixed" }
vim.bo.filetype = "markdown"
vim.api.nvim_buf_set_name(0, vim.fs.joinpath(root, ".tests", "integration.md"))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Fixture" })
local preview = require("config.gitlab_preview")
assert(not preview.is_running(), "require だけでは起動しない")
preview.start()
local port, prefix = assert(preview.url()):match("^http://127%.0%.0%.1:(%d+)(/.*)$")
local js = [[
const http=require('node:http');
const req=http.get({hostname:'127.0.0.1',port:Number(process.argv[1]),path:process.argv[2]},res=>{
  let text='';res.setEncoding('utf8');res.on('data',v=>{text+=v;if(process.argv[3]==='event' && text.includes('event: render\n')){process.stdout.write(text);req.destroy();}});
  res.on('end',()=>{if(process.argv[3]!=='event')process.stdout.write(text)});
});req.on('error',()=>process.exit(1));
]]
local function get(path, event)
  local result
  local proc = vim.system(
    { "node", "-e", js, port, prefix .. path, event and "event" or "page" },
    { text = true },
    function(res)
      result = res
    end
  )
  if not vim.wait(10000, function()
    return result ~= nil
  end, 10) then
    proc:kill(15)
    error("統合試験の HTTP が時間切れ")
  end
  assert(result.code == 0, "統合試験の HTTP に失敗")
  return result.stdout
end
local function config()
  local page = get("")
  local text = assert(page:match('<script id="gp%-config" type="application/json">(.-)</script>'))
  return vim.json.decode(text)
end
local ok, err = xpcall(function()
  local initial = config()
  assert(initial.assets == vim.NIL and initial.notice:find("未導入", 1, true), "未導入でもページを表示")
  assert(
    initial.appearance.theme == "dark" and initial.appearance.width == "fixed",
    "初期設定をページへ渡す"
  )
  local events = get("_/events", true)
  assert(
    events:find('"mode":"api"', 1, true) and events:find('"assets_id":false', 1, true),
    "API とスタイルの未導入を区別"
  )
  local files = {}
  for _, name in ipairs({ "app.css", "tree.css", "fonts.css", "color.css", "icons.svg" }) do
    files[name] = { body = "fixture", mime = "text/plain", sha256 = vim.fn.sha256("fixture") }
  end
  installed = {
    id = "fixture-2",
    version = "fixture",
    files = files,
    styles = {
      light = { "app.css", "tree.css", "fonts.css", "color.css" },
      dark = { "app.css", "tree.css", "fonts.css", "color.css" },
    },
    sprite = "icons.svg",
  }
  -- headless の別プロセスで導入した場合も、稼働中の開き直しで読み直す。
  preview.start()
  assert(config().assets.id == "fixture-2", "別プロセスの導入を開き直しで反映")
  installed.id = "fixture-3"
  package.loaded["config.gitlab_preview.installer"] = {
    run = function(opts)
      opts.on_done(true)
      return true
    end,
  }
  preview.install()
  local updated = config()
  assert(updated.assets.id == "fixture-3" and updated.notice == "", "導入後にページのキャッシュを更新")
  events = get("_/events", true)
  assert(events:find('"assets_id":"fixture-3"', 1, true), "開いているタブへ新しい版を通知")
  local spec = dofile(vim.fs.joinpath(root, "lua", "plugins", "gitlab-preview.lua"))
  spec[1].config()
  assert(vim.api.nvim_get_commands({}).GitLabPreviewInstall, "明示的な導入コマンド")
end, debug.traceback)
preview.stop()
vim.env = original_env
vim.g.gitlab_preview_browser = nil
vim.g.gitlab_preview_appearance = nil
if not ok then
  error(err)
end
print("GitLab preview integration: PASS")
