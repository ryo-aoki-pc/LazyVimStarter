-- GitLab プレビューの GitLab 側: 送り先の決定、git remote の解析、Markdown API の呼び出し。
--
-- トークンの扱い (変えるときは README と docs/setup.md も直す):
--  - 本文を送るのは GITLAB_TOKEN があるときだけ。無ければ呼ぶ側 (init.lua) が何も送らない
--  - 送り先は GITLAB_HOST (glab と同じ名前)、無ければ gitlab.com だけ。git の remote のホスト名からは
--    推測しない (名前に gitlab を含む無関係なホストへ、トークンと本文を送ってしまわないように)
--  - curl には環境変数からトークンを取り込ませる (--variable)。コマンドライン・一時ファイルには出さない
local M = {}

--- GITLAB_HOST から API の送り先を決める。ホスト名だけ (gitlab.example.com) でも URL でもよい。
---@return { base: string, origin: string, host: string, path: string }
function M.api()
  local raw = vim.trim(vim.env.GITLAB_HOST or "")
  if raw == "" then
    raw = "https://gitlab.com"
  end
  if not raw:find("^%a[%w+.-]*://") then
    raw = "https://" .. raw
  end
  raw = raw:gsub("/+$", "")
  local scheme, rest = raw:match("^(%a[%w+.-]*)://(.*)$")
  local authority, path = rest:match("^([^/]*)(.*)$")
  authority = authority:gsub("^.*@", "") -- 利用者名などは送り先に含めない
  local host = authority:match("^%[(.-)%]") or authority:match("^([^:]+)") or authority
  return {
    base = scheme:lower() .. "://" .. authority .. path, -- API は base .. "/api/v4/…"
    origin = scheme:lower() .. "://" .. authority,
    host = host:lower(),
    path = path, -- GitLab をサブパス (https://example.com/gitlab) で動かしているとき "/gitlab"
  }
end

--- git の remote の URL から、ホスト名と path (group/sub/project) を取り出す。
--- https://… / ssh://… / scp 形式 (git@host:group/project.git) を扱う。ローカルのパスは nil。
---@param url string
---@return { host: string, path: string, scheme: string? }?
function M.parse_remote(url)
  url = vim.trim(url or "")
  if url == "" then
    return nil
  end
  local host, path
  local scheme, rest = url:match("^(%a[%w+.-]*)://(.*)$")
  if scheme then
    scheme = scheme:lower()
    if scheme == "file" then
      return nil
    end
    local authority
    authority, path = rest:match("^([^/]*)(.*)$")
    authority = authority:gsub("^.*@", "")
    host = authority:match("^%[(.-)%]") or authority:match("^([^:]+)")
  else
    -- Windows のドライブ (C:\ や C:/) と、相対・絶対のローカルのパスは除く
    if url:match("^%a:[/\\]") or url:match("^[/\\.~]") then
      return nil
    end
    local h, p = url:match("^([^/]-%[[^%]]+%]):(.+)$") -- [::1] のような IPv6
    if not h then
      h, p = url:match("^([^:/]+):(.+)$")
    end
    if not h then
      return nil
    end
    host = h:gsub("^.*@", "")
    host = host:match("^%[(.-)%]$") or host
    path = p
  end
  if not host or host == "" then
    return nil
  end
  path = (path or ""):gsub("^/+", ""):gsub("/+$", ""):gsub("%.git$", "")
  if path == "" then
    return nil
  end
  return { host = host:lower(), path = path, scheme = scheme }
end

local function git(dir, args)
  local ok, res = pcall(function()
    return vim.system(vim.list_extend({ "git", "-C", dir }, args), { text = true }):wait(3000)
  end)
  if ok and res and res.code == 0 then
    local out = vim.trim(res.stdout or "")
    return out ~= "" and out or nil
  end
end

local function norm(path)
  return (path:gsub("\\", "/"):gsub("/+$", ""))
end

--- ディレクトリごとの文脈: リポジトリのルートと、送るときの project。
--- git を同期で呼ぶので、呼ぶ側 (init.lua) がディレクトリごとに覚えておく。
---@param dir string .md のあるディレクトリ
---@return { root: string, api: table, project: string? }
function M.context(dir)
  local real_dir = norm(vim.uv.fs_realpath(dir) or dir)
  local top = git(dir, { "rev-parse", "--show-toplevel" })
  local root = top and norm(vim.uv.fs_realpath(top) or top) or real_dir
  local api = M.api()
  local project
  local remote = top and M.parse_remote(git(dir, { "remote", "get-url", "origin" }) or "")
  if remote and remote.host == api.host then
    project = remote.path
    -- サブパスで動かしている GitLab の https の remote は、path にサブパスが付いている
    local sub = api.path:gsub("^/+", "")
    if remote.scheme and sub ~= "" and project:sub(1, #sub + 1) == sub .. "/" then
      project = project:sub(#sub + 2)
    end
  end
  return { root = root, api = api, project = project }
end

--- root から path への相対 (区切りは /)。root の外なら nil。Windows では大文字と小文字を区別しない。
---@param root string
---@param path string
---@return string?
function M.relpath(root, path)
  root, path = norm(root), norm(path)
  local a, b = path, root
  if vim.fn.has("win32") == 1 then
    a, b = a:lower(), b:lower()
  end
  if a == b then
    return ""
  end
  if a:sub(1, #b + 1) == b .. "/" then
    return path:sub(#root + 2)
  end
end

local function classify(res)
  if res.code ~= 0 then
    local line = (res.stderr or ""):match("[^\r\n]+")
    return { kind = "network", reason = line or ("curl が " .. res.code .. " で終わった") }
  end
  local body, status = (res.stdout or ""):match("^(.*)\n(%d%d%d)$")
  status = tonumber(status)
  if not status then
    return { kind = "http", status = 0 }
  end
  if status >= 200 and status < 300 then -- POST なので 201 が返る
    local ok, data = pcall(vim.json.decode, body)
    if ok and type(data) == "table" and type(data.html) == "string" then
      return { kind = "ok", html = data.html }
    end
    return { kind = "http", status = status }
  elseif status == 401 or status == 403 then
    return { kind = "auth", status = status }
  elseif status == 404 then
    -- 読めない project を渡したときは {"message":"404 Project Not Found"}。API 自体が無ければ別の 404
    return { kind = "notfound", status = status, project = body:find("Project", 1, true) ~= nil }
  elseif status == 429 then
    return { kind = "ratelimit", status = status }
  end
  return { kind = "http", status = status }
end

--- GitLab の Markdown API で描かせる。結果は cb に 1 度だけ、通常の文脈 (vim.schedule の後) で渡す。
--- project が読めない (404 Project Not Found) ときは、project を外して 1 度だけ送り直す。
---@param text string
---@param ctx { api: table, project: string? }
---@param cb fun(result: { kind: string, html: string?, status: integer?, reason: string?, project_dropped: boolean? })
---@return fun() cancel 送信中のものを止める (その後は cb を呼ばない)
function M.render(text, ctx, cb)
  local proc, cancelled = nil, false
  local function run(project, dropped)
    local cmd = {
      "curl",
      "--silent",
      "--show-error",
      "--compressed",
      "--proto",
      "=http,https",
      "--connect-timeout",
      "5",
      "--max-time",
      "20",
      -- トークンは環境変数から取り込み、ヘッダーの中で展開させる (curl 8.3 以上)。
      -- コマンドラインに値を書かないので、ほかのプロセスからプロセスの一覧で見られない
      "--variable",
      "%GITLAB_TOKEN",
      "--expand-header",
      "PRIVATE-TOKEN: {{GITLAB_TOKEN:trim}}",
      "--header",
      "Content-Type: application/json",
      "--header",
      "Accept: application/json",
      "--data-binary",
      "@-", -- 本文は標準入力から (一時ファイルに書かない)
      "--write-out",
      "\\n%{http_code}",
      ctx.api.base .. "/api/v4/markdown",
    }
    local body = vim.json.encode({ text = text, gfm = true, project = project })
    local ok, obj = pcall(vim.system, cmd, { stdin = body, text = true, timeout = 25000 }, function(res)
      -- ここは fast context。結果の解釈も含めて、通常の文脈に移してから行う
      vim.schedule(function()
        if cancelled then
          return
        end
        local r = classify(res)
        if r.kind == "notfound" and r.project and project then
          return run(nil, true)
        end
        r.project_dropped = dropped
        cb(r)
      end)
    end)
    if not ok then
      -- curl が無いなど。vim.system は起動に失敗すると例外を投げる
      vim.schedule(function()
        if not cancelled then
          cb({ kind = "network", reason = tostring(obj) })
        end
      end)
      return
    end
    proc = obj
  end
  run(ctx.project, false)
  return function()
    cancelled = true
    if proc and not proc:is_closing() then
      pcall(proc.kill, proc, 15)
    end
  end
end

return M
