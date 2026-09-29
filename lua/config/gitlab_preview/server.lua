-- GitLab プレビューのローカル HTTP サーバー (vim.uv)。
-- ページ・JS・CSS・SSE (_/events) と、リポジトリの中のファイル (画像など) を返す。
--
-- 守り:
--  - 127.0.0.1 だけで待ち受け、URL に推測できない token を入れる (http://127.0.0.1:PORT/<token>/)。
--    同じマシンのほかのユーザーやプロセスは、token を知らなければ何も読めない
--  - Host が 127.0.0.1 / localhost でない要求は拒む (DNS rebinding で、ほかのサイトから読まれないように)
--  - Sec-Fetch-Site が cross-site / same-site の要求も拒む。CORS のヘッダーは付けない
--  - ファイルはリポジトリのルートの内側だけ (resolve() を参照)。.git は返さない
--
-- 注意: vim.uv のコールバックは fast context で走り、vim.api / vim.fn / vim.fs (vim.env を読む) を
-- 呼べない。ここの処理は、文字列・vim.uv・前もって用意した値だけで完結させている。
local uv = vim.uv

local M = {}

local IS_WIN = vim.fn.has("win32") == 1
local MAX_HEAD = 16 * 1024 -- 要求のヘッダーの上限
local MAX_QUEUE = 8 * 1024 * 1024 -- SSE の書き込みが溜まりすぎたクライアントは切る
local CHUNK = 64 * 1024 -- ファイルを流す単位

-- Neovim のセッション中は同じポートと token を使い回す。プレビューを止めて開き直しても、
-- 開いたままのタブ (EventSource は自動で再接続する) が同じ URL のまま戻ってこられるように。
local session = { port = nil, token = nil }

---@type { tcp: uv.uv_tcp_t, port: integer, token: string, clients: table<uv.uv_tcp_t, true>, last: table<string, string>, opts: table }|nil
local server = nil

local REASON = {
  [200] = "OK",
  [301] = "Moved Permanently",
  [304] = "Not Modified",
  [400] = "Bad Request",
  [403] = "Forbidden",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [431] = "Request Header Fields Too Large",
  [500] = "Internal Server Error",
}

local MIME = {
  png = "image/png",
  jpg = "image/jpeg",
  jpeg = "image/jpeg",
  gif = "image/gif",
  webp = "image/webp",
  avif = "image/avif",
  svg = "image/svg+xml",
  bmp = "image/bmp",
  ico = "image/x-icon",
  mp4 = "video/mp4",
  webm = "video/webm",
  mov = "video/quicktime",
  mp3 = "audio/mpeg",
  ogg = "audio/ogg",
  wav = "audio/wav",
  pdf = "application/pdf",
  txt = "text/plain; charset=utf-8",
  md = "text/plain; charset=utf-8",
  csv = "text/plain; charset=utf-8",
}

-- Windows で予約されているデバイス名 (拡張子を付けても、どのディレクトリでもデバイスを指す)
local DEVICES = { con = true, prn = true, aux = true, nul = true, ["conin$"] = true, ["conout$"] = true }

local function close(sock)
  if sock:is_closing() then
    return
  end
  local req = sock:shutdown(function()
    if server then
      server.clients[sock] = nil
    end
    if not sock:is_closing() then
      sock:close()
    end
  end)
  if not req then
    sock:close()
  end
end

local function head(status, headers)
  local out = { ("HTTP/1.1 %d %s"):format(status, REASON[status] or "") }
  for k, v in pairs(headers) do
    out[#out + 1] = k .. ": " .. v
  end
  return table.concat(out, "\r\n") .. "\r\n\r\n"
end

local function common(headers)
  headers["Connection"] = "close" -- keep-alive はしない。応答ごとに閉じる
  headers["X-Content-Type-Options"] = "nosniff"
  headers["Referrer-Policy"] = "no-referrer" -- token の入った URL を、外へのリンクやリソースの取得で漏らさない
  return headers
end

-- 本文ごと 1 回で書いて閉じる
local function send(sock, status, headers, body, no_body)
  headers = common(headers or {})
  body = body or (status >= 400 and (REASON[status] or "") or "")
  if status ~= 304 then
    headers["Content-Length"] = tostring(#body)
  end
  if #body > 0 and not headers["Content-Type"] then
    headers["Content-Type"] = "text/plain; charset=utf-8"
  end
  sock:write(head(status, headers) .. ((no_body or status == 304) and "" or body), function()
    close(sock)
  end)
end

local function event(name, data)
  return "event: " .. name .. "\ndata: " .. vim.json.encode(data) .. "\n\n"
end

--- 要求のパス (token の後ろ、パーセントエンコードのまま) を、root の内側の実ファイルに解決する。
--- 純粋関数 (状態を持たない) なので単体で確かめられる。
---@param root string リポジトリのルート。realpath 済み
---@param raw string
---@param is_win? boolean 省略時は実行中の OS
---@return integer status 200 / 400 / 403 / 404
---@return string? real 実ファイルのパス (区切りは /)
function M.resolve(root, raw, is_win)
  if is_win == nil then
    is_win = IS_WIN
  end
  if raw:find("%00", 1, true) then
    return 400
  end
  local path = raw:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  -- 制御文字とバックスラッシュ (Windows では区切りになる) を拒む。Windows ではドライブ・
  -- 代替データストリームに使う ":" も拒む
  if path:find("[%z\1-\31\127]") or path:find("\\", 1, true) or (is_win and path:find(":", 1, true)) then
    return 400
  end
  local segs = {}
  for seg in path:gmatch("[^/]+") do
    if seg == ".." then
      return 403
    end
    if seg ~= "." then
      if is_win then
        -- Windows は末尾の . と空白を捨てて開くので、別名での読み出しになる。デバイス名も拒む
        local stem = (seg:match("^[^.]*") or ""):lower()
        if seg:find("[%. ]$") or DEVICES[stem] or stem:match("^com%d$") or stem:match("^lpt%d$") then
          return 400
        end
      end
      if seg:lower() == ".git" then
        return 403
      end
      segs[#segs + 1] = seg
    end
  end
  if #segs == 0 then
    return 404
  end

  local base = root:gsub("\\", "/"):gsub("/+$", "")
  local real = uv.fs_realpath(base .. "/" .. table.concat(segs, "/"))
  if not real then
    return 404
  end
  real = real:gsub("\\", "/")
  -- シンボリックリンクやジャンクションで外へ出たものも、realpath の比較で弾く
  local a, b = real, base .. "/"
  if is_win then
    a, b = a:lower(), b:lower()
  end
  if a:sub(1, #b) ~= b then
    return 403
  end
  for seg in real:sub(#b + 1):gmatch("[^/]+") do
    if seg:lower() == ".git" then
      return 403
    end
  end
  return 200, real
end

local function serve_file(sock, rel, hdr, no_body)
  local root = server and server.opts.root()
  if not root then
    return send(sock, 404)
  end
  local status, real = M.resolve(root, rel)
  if status ~= 200 or not real then
    return send(sock, status)
  end
  local st = uv.fs_stat(real)
  if not st or st.type ~= "file" then
    return send(sock, 404) -- ディレクトリの一覧は出さない
  end
  local ext = (real:match("%.([^./]+)$") or ""):lower()
  local etag = ('W/"%d-%d-%d"'):format(st.size, st.mtime.sec, st.mtime.nsec)
  local headers = {
    ["Content-Type"] = MIME[ext] or "application/octet-stream",
    ["Cache-Control"] = "no-cache",
    ["ETag"] = etag,
  }
  -- リポジトリの .svg や .html を直接開かれても、この origin でスクリプトを走らせない
  -- (PDF はブラウザの表示機能が sandbox では動かないので除く)
  if ext ~= "pdf" then
    headers["Content-Security-Policy"] = "sandbox"
  end
  if hdr["if-none-match"] == etag then
    return send(sock, 304, headers)
  end
  local fd = uv.fs_open(real, "r", 0)
  if not fd then
    return send(sock, 404)
  end
  headers = common(headers)
  headers["Content-Length"] = tostring(st.size)
  local offset = 0
  local function finish()
    uv.fs_close(fd)
    close(sock)
  end
  local function pump(err)
    if err or no_body or sock:is_closing() then
      return finish()
    end
    local data = uv.fs_read(fd, CHUNK, offset)
    if not data or data == "" then
      return finish()
    end
    offset = offset + #data
    sock:write(data, pump)
  end
  sock:write(head(200, headers), pump)
end

local function open_events(sock, no_body)
  local headers = common({
    ["Content-Type"] = "text/event-stream; charset=utf-8",
    ["Cache-Control"] = "no-store",
  })
  if no_body then
    return send(sock, 200, headers, "", true)
  end
  -- 長さを付けない応答の本文は、接続を閉じたところで終わる (HTTP/1.1)。ここでは閉じるまで流し続ける。
  -- 接続した時点で、最後の render と scroll を送り直す (開き直したタブや再接続したタブのため)
  local last = server.last
  sock:write(head(200, headers) .. "retry: 1000\n\n" .. (last.render or "") .. (last.scroll or ""))
  server.clients[sock] = true
end

local function handle(sock, text)
  local lines = {}
  for line in (text .. "\r\n"):gmatch("(.-)\r?\n") do
    lines[#lines + 1] = line
  end
  local method, target = (lines[1] or ""):match("^(%u+) (%S+) HTTP/1%.[01]$")
  if not method then
    return send(sock, 400)
  end
  local hdr = {}
  for i = 2, #lines do
    local k, v = lines[i]:match("^([^:%s]+):%s*(.-)%s*$")
    if k then
      hdr[k:lower()] = v
    end
  end

  local port = tostring(server.port)
  if not hdr.host then
    return send(sock, 400)
  end
  if hdr.host ~= "127.0.0.1:" .. port and hdr.host ~= "localhost:" .. port then
    return send(sock, 403)
  end
  local site = hdr["sec-fetch-site"]
  if site and site ~= "same-origin" and site ~= "none" then
    return send(sock, 403)
  end
  if method ~= "GET" and method ~= "HEAD" then
    return send(sock, 405, { Allow = "GET, HEAD" })
  end
  local no_body = method == "HEAD"

  local path = target:match("^[^?#]*")
  local base = "/" .. server.token
  if path == base then
    return send(sock, 301, { Location = base .. "/" }, "", no_body)
  end
  if path:sub(1, #base + 1) ~= base .. "/" then
    return send(sock, 404)
  end
  local rel = path:sub(#base + 2)

  local page = server.opts.page
  if rel == "" then
    return send(sock, 200, {
      ["Content-Type"] = "text/html; charset=utf-8",
      ["Cache-Control"] = "no-store",
      ["Content-Security-Policy"] = server.opts.csp,
    }, page.html, no_body)
  elseif rel == "_/preview.js" then
    return send(
      sock,
      200,
      { ["Content-Type"] = "text/javascript; charset=utf-8", ["Cache-Control"] = "no-store" },
      page.js,
      no_body
    )
  elseif rel == "_/preview.css" then
    return send(
      sock,
      200,
      { ["Content-Type"] = "text/css; charset=utf-8", ["Cache-Control"] = "no-store" },
      page.css,
      no_body
    )
  elseif rel == "_/events" then
    return open_events(sock, no_body)
  end
  return serve_file(sock, rel, hdr, no_body)
end

local function on_connection(err)
  if err or not server then
    return
  end
  local sock = uv.new_tcp()
  if not sock then
    return
  end
  if not server.tcp:accept(sock) then
    sock:close()
    return
  end
  local buf, handled = "", false
  sock:read_start(function(rerr, chunk)
    if rerr or not chunk then
      -- 相手が閉じた (SSE のタブを閉じた・再読み込みした) ときもここに来る
      if server then
        server.clients[sock] = nil
      end
      if not sock:is_closing() then
        sock:close()
      end
      return
    end
    if handled then
      return -- 応答した後に届いたものは読み捨てる (SSE の接続は、閉じたことを知るために読み続ける)
    end
    buf = buf .. chunk
    local e = buf:find("\r\n\r\n", 1, true)
    if not e then
      if #buf > MAX_HEAD then
        handled = true
        send(sock, 431)
      end
      return
    end
    handled = true
    local ok = pcall(handle, sock, buf:sub(1, e - 1))
    if not ok and not sock:is_closing() then
      pcall(send, sock, 500)
    end
  end)
end

---@param opts { page: { html: string, js: string, css: string }, csp: string, root: fun(): string? }
---@return boolean? ok
---@return string? err
function M.start(opts)
  if server then
    return true
  end
  local token = session.token
  if not token then
    token = (uv.random(16):gsub(".", function(c)
      return ("%02x"):format(c:byte())
    end))
  end
  local function try(port)
    local tcp = uv.new_tcp()
    if not tcp then
      return nil, "new_tcp"
    end
    local ok, err = tcp:bind("127.0.0.1", port)
    if ok then
      ok, err = tcp:listen(64, on_connection)
    end
    if not ok then
      tcp:close()
      return nil, err
    end
    return tcp
  end
  local tcp, err
  if session.port then
    tcp = try(session.port) -- 前のポートが別のプロセスに取られていたら、空いているポートにする
  end
  if not tcp then
    tcp, err = try(0)
  end
  if not tcp then
    return nil, err
  end
  local port = tcp:getsockname().port
  session.port, session.token = port, token
  server = { tcp = tcp, port = port, token = token, clients = {}, last = {}, opts = opts }
  return true
end

--- SSE で全てのタブに送る。render と scroll は、後から接続したタブのために最後の 1 件を覚えておく。
---@param name "render"|"scroll"
---@param data table
function M.broadcast(name, data)
  if not server then
    return
  end
  local chunk = event(name, data)
  server.last[name] = chunk
  for sock in pairs(server.clients) do
    if sock:is_closing() then
      server.clients[sock] = nil
    elseif sock:get_write_queue_size() > MAX_QUEUE then
      server.clients[sock] = nil
      sock:close()
    else
      sock:write(chunk)
    end
  end
end

--- タブに止めたことを伝えてから、接続と待ち受けを閉じる。
---@param reason "stop"|"exit"
---@return table<uv.uv_tcp_t, true> clients 閉じ終わるまで待つときに見る
function M.close(reason)
  if not server then
    return {}
  end
  local s = server
  server = nil
  local bye = event("stop", { reason = reason })
  for sock in pairs(s.clients) do
    if sock:is_closing() then
      s.clients[sock] = nil
    else
      sock:write(bye, function()
        if not sock:is_closing() then
          sock:shutdown(function()
            s.clients[sock] = nil
            if not sock:is_closing() then
              sock:close()
            end
          end)
        end
      end)
    end
  end
  if not s.tcp:is_closing() then
    s.tcp:close()
  end
  return s.clients
end

---@return string?
function M.url()
  return server and ("http://127.0.0.1:%d/%s/"):format(server.port, server.token) or nil
end

function M.running()
  return server ~= nil
end

function M.client_count()
  local n = 0
  for sock in pairs(server and server.clients or {}) do
    if not sock:is_closing() then
      n = n + 1
    end
  end
  return n
end

return M
