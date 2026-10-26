-- 公式資産のブラウザ試験用。取得済みの資産だけを既存の Lua サーバーで配信する。
local source = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)
local data_dir, url_file, stop_file = arg[1], arg[2], arg[3]
assert(data_dir and url_file and stop_file, "data-dir、URL と終了通知のファイルを指定する")
local assets = require("config.gitlab_preview.assets")
local bundle, err = assets.load(data_dir)
assert(bundle, err)
local server = require("config.gitlab_preview.server")
local page_dir = vim.fs.joinpath(root, "lua", "config", "gitlab_preview", "page")
local function read(path)
  local f = assert(io.open(path, "rb"))
  local body = f:read("*a")
  f:close()
  return body
end
local config = vim.json.encode(assets.page_config(bundle)):gsub("<", "\\u003c")
local html = read(vim.fs.joinpath(page_dir, "index.html")):gsub("{{LIBS}}", "{}"):gsub("{{CONFIG}}", function()
  return config
end)
assert(server.start({
  page = {
    html = html,
    js = read(vim.fs.joinpath(page_dir, "preview.js")),
    css = read(vim.fs.joinpath(page_dir, "preview.css")),
    fallback = read(vim.fs.joinpath(page_dir, "fallback.css")),
  },
  assets = bundle,
  csp = table.concat({
    "default-src 'none'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "font-src 'self' data:",
    "img-src 'self' data:",
    "connect-src 'self'",
    "base-uri 'none'",
    "frame-ancestors 'none'",
  }, "; "),
  root = function()
    return root
  end,
}))

-- GitLab の API が返すクラス・sourcepos と、日本語の折り返しを含む公開用の見本。
local content = {
  '<h1 data-sourcepos="1:1-1:20">GitLab プレビューの表示確認</h1>',
  '<p data-sourcepos="2:1-2:90">本文には GitLab Sans、日本語の代替フォント、<strong>太字</strong>、<em>斜体</em>、<code>inline_code</code> を混ぜる。</p>',
  '<h2 data-sourcepos="3:1-3:20">表とコード</h2>',
  '<table data-sourcepos="4:1-8:40"><thead><tr><th>項目</th><th>内容</th><th>状態</th></tr></thead><tbody><tr><td>フォント</td><td>GitLab Sans / GitLab Mono</td><td>実ファイルを読み込む</td></tr><tr><td>配色</td><td>ライトとダークで本文を切り替える</td><td>公式 Dracula のコード配色</td></tr><tr><td>本文幅</td><td>全幅と固定幅</td><td><code>1600px</code></td></tr></tbody></table>',
  '<div class="markdown-code-block" data-sourcepos="9:1-13:3"><pre class="code highlight"><code><span class="kd">const</span> <span class="nx">message</span> <span class="o">=</span> <span class="s">"Hello, GitLab"</span><span class="p">;</span>\n<span class="c1">// 日本語と英数字のコード</span>\n<span class="nx">console</span><span class="p">.</span><span class="nx">log</span><span class="p">(</span><span class="nx">message</span><span class="p">);</span></code></pre></div>',
  '<blockquote data-sourcepos="14:1-15:30"><p>引用の線、余白、文字色を確認する。</p></blockquote>',
  '<details open data-sourcepos="16:1-19:3"><summary>折りたたみの内容</summary><p>本文を更新せずに配色と幅を切り替える。</p></details>',
  '<p data-sourcepos="20:1-20:30">GitLab アイコン <svg width="16" height="16" id="official-sprite"><use href="/assets/'
    .. bundle.sprite
    .. '#link"></use></svg></p>',
}
for line = 21, 90 do
  content[#content + 1] = ('<p id="line-%d" data-sourcepos="%d:1-%d:120">%d: %s</p>'):format(
    line,
    line,
    line,
    line,
    string.rep(
      "日本語の文章で、本文幅を変えたときの改行とスクロール位置を確認する。",
      4
    )
  )
end
server.broadcast("render", {
  mode = "api",
  file = "公開用の表示見本.md",
  dir = "",
  html = table.concat(content, "\n"),
  gitlab = { origin = "https://gitlab.com", host = "gitlab.com", path = "", project = "gitlab-org/gitlab-foss" },
  assets_id = bundle.id,
})
server.broadcast("scroll", { line = 1, ratio = 0, lines = 90 })
vim.fn.writefile({ assert(server.url()) }, url_file)
vim.wait(120000, function()
  return vim.uv.fs_stat(stop_file) ~= nil
end, 20)
server.close()
vim.wait(50, function()
  return false
end, 10)
