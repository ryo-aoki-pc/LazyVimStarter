-- 実 HTTP で資産の許可リスト、ヘッダー、旧版の保持、既存ファイルの閉じ込めを確かめる。
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)
local server = require("config.gitlab_preview.server")
local temp = vim.fs.joinpath(root, ".tests", "server-" .. vim.uv.os_getpid())
vim.fn.mkdir(temp, "p")
local f = assert(io.open(vim.fs.joinpath(temp, "project.txt"), "wb"))
f:write("project fixture")
f:close()
local function bundle(id, body)
  return {
    id = id,
    files = {
      ["app.css"] = { mime = "text/css; charset=utf-8", body = body, sha256 = vim.fn.sha256(body) },
      ["font.woff2"] = { mime = "font/woff2", body = "a\0b", sha256 = vim.fn.sha256("a\0b") },
    },
  }
end
local first = bundle("test-1", ".md{color:red}")
assert(server.start({
  page = { html = "fixture page", js = "", css = "", fallback = "fallback fixture" },
  csp = "default-src 'none'; font-src 'self'",
  root = function()
    return vim.uv.fs_realpath(temp)
  end,
  assets = first,
}))
local base = assert(server.url())
local port, prefix = base:match("^http://127%.0%.0%.1:(%d+)(/.*)$")
local js = [[
const http=require('node:http');
const req=http.request({hostname:'127.0.0.1',port:Number(process.argv[1]),path:process.argv[2],method:process.argv[3],headers:JSON.parse(process.argv[4])},res=>{
  const chunks=[];res.on('data',v=>chunks.push(v));res.on('end',()=>process.stdout.write(JSON.stringify({status:res.statusCode,headers:res.headers,body:Buffer.concat(chunks).toString('base64')})));
});req.on('error',()=>process.exit(1));req.end();
]]
local function request(path, method, headers)
  local result
  local proc = vim.system(
    { "node", "-e", js, port, prefix .. path, method or "GET", vim.json.encode(headers or vim.empty_dict()) },
    { text = true },
    function(res)
      result = res
    end
  )
  if not vim.wait(10000, function()
    return result ~= nil
  end, 10) then
    proc:kill(15)
    error("HTTP の試験が時間切れ")
  end
  assert(result.code == 0, "HTTP の要求に失敗")
  local res = vim.json.decode(result.stdout)
  res.body = vim.base64.decode(res.body)
  return res
end
local ok, err = xpcall(function()
  local r = request("_/assets/test-1/app.css")
  assert(
    r.status == 200 and r.body == first.files["app.css"].body,
    "登録した CSS を配信: " .. r.status .. " " .. r.body
  )
  assert(r.headers["content-type"] == "text/css; charset=utf-8", "CSS の MIME")
  assert(r.headers["x-content-type-options"] == "nosniff", "MIME を固定")
  assert(r.headers["referrer-policy"] == "no-referrer", "参照元を送らない")
  local etag = r.headers.etag
  assert(request("_/assets/test-1/app.css", "GET", { ["If-None-Match"] = etag }).status == 304, "検証済み ETag")
  r = request("_/assets/test-1/font.woff2", "HEAD")
  assert(r.status == 200 and r.body == "" and r.headers["content-length"] == "3", "HEAD の長さと本文")
  r = request("_/assets/test-1/font.woff2")
  assert(r.body == "a\0b" and r.headers["content-type"] == "font/woff2", "バイナリーフォント")
  assert(request("_/assets/test-1/missing.css").status == 404, "未登録資産")
  assert(request("_/assets/test-2/app.css").status == 404, "未登録版")
  assert(request("_/assets/test-1/../project.txt").status == 404, "資産の外を読ませない")
  assert(request("_/assets/test-1/%2e%2e/project.txt").status == 404, "エンコードした脱出")
  assert(request("_/assets/test-1/app.css", "POST").status == 405, "配信は読み取りだけ")
  assert(request("_/assets/test-1/app.css", "GET", { Host = "example.invalid" }).status == 403, "Host を検査")
  assert(
    request("_/assets/test-1/app.css", "GET", { ["Sec-Fetch-Site"] = "cross-site" }).status == 403,
    "別サイトからの要求"
  )
  assert(request("project.txt").body == "project fixture", "リポジトリのファイル配信を維持")
  assert(request("_/fallback.css").body == "fallback fixture", "独自 CSS へ退避")
  server.update_page(
    { html = "updated fixture", js = "", css = "" },
    "default-src 'none'",
    bundle("test-2", "new fixture")
  )
  assert(request("").body == "updated fixture", "取得後にページを交換")
  assert(request("_/assets/test-2/app.css").body == "new fixture", "新しい版")
  assert(
    request("_/assets/test-1/app.css").body == first.files["app.css"].body,
    "開いていたタブの旧版を保持"
  )
end, debug.traceback)
server.close()
vim.wait(50, function()
  return false
end, 10)
assert(vim.fs.normalize(temp):sub(1, #root + 8) == root .. "/.tests/", "試験領域の外を削除しない")
vim.fn.delete(temp, "rf")
if not ok then
  error(err)
end
print("GitLab preview server: PASS")
