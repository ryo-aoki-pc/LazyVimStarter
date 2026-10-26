-- 通信や通常設定を使わず、導入済み資産の検証と初期設定を確かめる。
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)
local assets = require("config.gitlab_preview.assets")
local temp = vim.fs.joinpath(root, ".tests", "assets-" .. vim.uv.os_getpid())
vim.fn.mkdir(temp, "p")
local function write(path, body)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local f = assert(io.open(path, "wb"))
  f:write(body)
  f:close()
end
local manifest = {
  schema = 1,
  version = "test-1",
  files = {},
  styles = {
    light = { "app.css", "tree.css", "fonts.css", "white.css" },
    dark = { "app.css", "tree.css", "fonts.css", "dark.css" },
  },
  sprite = "icons.svg",
}
local bodies = {
  ["app.css"] = ":root{color:red}",
  ["tree.css"] = ".md{padding:1px}",
  ["fonts.css"] = "@font-face{font-family:test;src:url(font.woff2)}",
  ["white.css"] = ".highlight{color:blue}",
  ["dark.css"] = ".highlight{color:cyan}",
  ["icons.svg"] = '<svg xmlns="http://www.w3.org/2000/svg"/>',
  ["font.woff2"] = "a\0b\255\n",
  ["licenses/MIT.txt"] = "fixture license",
}
for name, body in pairs(bodies) do
  manifest.files[name] = { size = #body, sha256 = vim.fn.sha256(body) }
end
local lock = vim.json.encode({
  version = "test-1",
  files = manifest.files,
  styles = manifest.styles,
  sprite = manifest.sprite,
}) .. "\n"
local hash = vim.fn.sha256(lock)
local id = "test-1-" .. hash:sub(1, 12)
local bundle = vim.fs.joinpath(temp, "gitlab-preview", "assets", id)
local lock_path = vim.fs.joinpath(temp, "lock.json")
write(lock_path, lock)
manifest.id, manifest.lock_sha256 = id, hash
for name, body in pairs(bodies) do
  write(vim.fs.joinpath(bundle, name), body)
end
local function save()
  write(vim.fs.joinpath(bundle, "install.json"), vim.json.encode(manifest))
end
local function rejects(label)
  local loaded, notice = assets.load(temp, lock_path)
  assert(not loaded and notice:find("公式スタイル", 1, true), label)
end
local ok, err = xpcall(function()
  rejects("未導入を識別する")
  save()
  local loaded = assert(assets.load(temp, lock_path))
  assert(loaded.files["font.woff2"].body == "a\0b\255\n", "バイナリーの検証と保持")
  assert(loaded.files["font.woff2"].mime == "font/woff2", "フォントの MIME")
  vim.g.gitlab_preview_appearance = { theme = "dark", width = "fixed" }
  local config = assets.page_config(loaded)
  assert(config.appearance.theme == "dark" and config.appearance.width == "fixed", "利用者の初期設定")
  assert(config.assets.id == id and config.notice == "", "版の通知")
  vim.g.gitlab_preview_appearance = { theme = "invalid", width = "invalid" }
  config = assets.page_config(nil)
  assert(config.appearance.theme == "system" and config.appearance.width == "fluid", "不正値は既定値")
  assert(config.assets == vim.NIL and config.notice:find("未導入", 1, true), "描画方式と導入状態を区別")
  write(vim.fs.joinpath(bundle, "font.woff2"), "a\0c\255\n")
  rejects("同じサイズの破損も拒む")
  write(vim.fs.joinpath(bundle, "font.woff2"), "a\0b\255\n")
  manifest.files["../outside.css"] = { size = 0, sha256 = vim.fn.sha256("") }
  save()
  rejects("導入先の外のパスを拒む")
  manifest.files["../outside.css"] = nil
  manifest.styles.light[1] = "missing.css"
  save()
  rejects("未登録のスタイルを拒む")
  manifest.styles.light[1] = "app.css"
  manifest.lock_sha256 = string.rep("0", 64)
  save()
  rejects("別の lock を拒む")
  manifest.lock_sha256 = hash
  save()
  vim.fn.delete(vim.fs.joinpath(bundle, "licenses", "MIT.txt"))
  rejects("通知の欠落を拒む")
end, debug.traceback)
vim.g.gitlab_preview_appearance = nil
assert(vim.fs.normalize(temp):sub(1, #root + 8) == root .. "/.tests/", "試験領域の外を削除しない")
vim.fn.delete(temp, "rf")
if not ok then
  error(err)
end
print("GitLab preview assets: PASS")
