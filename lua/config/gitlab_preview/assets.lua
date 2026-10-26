-- 導入済みの公式スタイルを読み取るだけ。起動やプレビューから取得処理は呼ばない。
local M = {}
local dir = vim.fs.dirname(vim.fs.normalize(debug.getinfo(1, "S").source:sub(2)))

local MIME = {
  css = "text/css; charset=utf-8",
  woff2 = "font/woff2",
  woff = "font/woff",
  ttf = "font/ttf",
  eot = "application/vnd.ms-fontobject",
  svg = "image/svg+xml",
  png = "image/png",
  jpg = "image/jpeg",
  jpeg = "image/jpeg",
  gif = "image/gif",
  webp = "image/webp",
  avif = "image/avif",
  ico = "image/x-icon",
  txt = "text/plain; charset=utf-8",
  md = "text/plain; charset=utf-8",
  json = "application/json; charset=utf-8",
}

local function read(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local function relative(path)
  if type(path) ~= "string" or path == "" or not path:match("^[%w_./@%-]+$") or path:sub(1, 1) == "/" then
    return false
  end
  for part in path:gmatch("[^/]+") do
    if part == "." or part == ".." or part:lower() == ".git" then
      return false
    end
  end
  return not path:find("//", 1, true)
end

--- 全ファイルを検証してメモリーに保持する。HTTP の fast context ではファイルも vim.fn も使わない。
--- data_dir / lock_path は隔離した試験と headless 導入にも使う。
function M.load(data_dir, lock_path)
  local ok, result = pcall(function()
    local lock_text = read(lock_path or vim.fs.joinpath(dir, "assets.lock.json"))
    local lock = vim.json.decode(lock_text)
    assert(type(lock.version) == "string" and lock.version:match("^[%w_.%-]+$"), "資産の版が不正")
    local hash = vim.fn.sha256(lock_text)
    local id = lock.version .. "-" .. hash:sub(1, 12)
    local root = vim.fs.joinpath(data_dir or vim.fn.stdpath("data"), "gitlab-preview", "assets", id)
    local real_root = assert(vim.uv.fs_realpath(root), "資産が未導入")
    local manifest = vim.json.decode(read(vim.fs.joinpath(root, "install.json")))
    assert(
      manifest.schema == 1 and manifest.id == id and manifest.lock_sha256 == hash,
      "導入情報の版が不一致"
    )
    assert(manifest.version == lock.version and type(manifest.files) == "table", "導入情報が不正")
    assert(
      type(lock.files) == "table" and vim.deep_equal(lock.styles, manifest.styles) and lock.sprite == manifest.sprite,
      "固定した資産の構成が不一致"
    )
    local files = {}
    for path, item in pairs(manifest.files) do
      assert(relative(path) and type(item) == "table", "資産のパスが不正")
      local expected = assert(lock.files[path], "固定していない資産がある")
      assert(
        item.sha256 == (expected.output_sha256 or expected.sha256)
          and item.size == (expected.output_size or expected.size),
        "固定した資産の検証値が不一致"
      )
      local mime = MIME[(path:match("%.([^./]+)$") or ""):lower()]
      assert(
        mime and type(item.sha256) == "string" and item.sha256:match("^%x+$") and #item.sha256 == 64,
        "資産の情報が不正"
      )
      local full = assert(vim.uv.fs_realpath(vim.fs.joinpath(root, path)), "資産が不足")
      local base = real_root:gsub("\\", "/"):gsub("/+$", "") .. "/"
      local target = full:gsub("\\", "/")
      if vim.fn.has("win32") == 1 then
        base, target = base:lower(), target:lower()
      end
      assert(target:sub(1, #base) == base, "資産が導入先の外を指す")
      local body = read(full)
      assert(#body == item.size and vim.fn.sha256(body) == item.sha256, "資産のハッシュが不一致")
      files[path] = { body = body, sha256 = item.sha256, mime = mime }
    end
    for path in pairs(lock.files) do
      assert(files[path], "固定した資産または通知が不足")
    end
    local styles = manifest.styles
    assert(type(styles) == "table", "スタイルの一覧が不足")
    for _, theme in ipairs({ "light", "dark" }) do
      assert(type(styles[theme]) == "table" and #styles[theme] >= 4, "スタイルが不足")
      for _, path in ipairs(styles[theme]) do
        assert(files[path] and files[path].mime == MIME.css, "スタイルが未登録")
      end
    end
    assert(type(manifest.sprite) == "string" and files[manifest.sprite], "スプライトが不足")
    assert(next(files), "資産が不足")
    return { id = id, version = lock.version, files = files, styles = styles, sprite = manifest.sprite }
  end)
  if ok then
    return result
  end
  return nil, "公式スタイル未導入または破損。:GitLabPreviewInstall で取得する"
end

function M.page_config(loaded)
  local appearance = vim.g.gitlab_preview_appearance or {}
  if type(appearance) ~= "table" then
    appearance = {}
  end
  local theme = ({ system = true, light = true, dark = true })[appearance.theme] and appearance.theme or "system"
  local width = ({ fluid = true, fixed = true })[appearance.width] and appearance.width or "fluid"
  return {
    appearance = { theme = theme, width = width },
    assets = loaded and {
      id = loaded.id,
      version = loaded.version,
      styles = loaded.styles,
      sprite = loaded.sprite,
    } or vim.NIL,
    notice = loaded and "" or "公式スタイル未導入。:GitLabPreviewInstall で取得する",
  }
end

return M
