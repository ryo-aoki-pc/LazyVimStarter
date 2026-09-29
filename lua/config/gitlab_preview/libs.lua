-- GitLab プレビューのページがブラウザで読むライブラリ (jsDelivr)。
-- 版を固定し、SRI (integrity) を付けて読む。ページの CSP (server.lua) もこの表から組み立てるので、
-- 読み込みを許すのはここに書いたファイルだけになる。
-- 上げるときは url と sri を必ず一緒に書き換える (片方だけだと、ブラウザが読み込みを拒む):
--   版の確認: https://data.jsdelivr.com/v1/packages/npm/<名前>/resolved?specifier=<範囲>
--   SRI の計算: curl -sL <url> | openssl dgst -sha384 -binary | openssl base64 -A (先頭に "sha384-" を付ける)
-- mermaid と KaTeX の版は GitLab 本体が使っている版とは一致しない (描画の細部が違うことがある)。
local CDN = "https://cdn.jsdelivr.net/npm/"

return {
  -- 近似表示 (GitLab の API を使えないとき) の Markdown の描画
  markdownit = {
    url = CDN .. "markdown-it@14.3.2/dist/markdown-it.min.js",
    sri = "sha384-hxAvKEbHozQqowCqu4B3mOihRnvATKzN8DX89pnQPo00/TFaxvQpmBgbE77Zjv61",
    global = "markdownit",
  },
  footnote = {
    url = CDN .. "markdown-it-footnote@4.0.0/dist/markdown-it-footnote.min.js",
    sri = "sha384-7mE/Iobn0ulfWG/11wQHPJLIV11r3mVxTdSnuNIL71f/DM1wFjtMREh+nxliUVdY",
    global = "markdownitFootnote",
  },
  -- 数式。GitLab も KaTeX で、HTML の .js-render-math をブラウザ側で描く
  katex = {
    url = CDN .. "katex@0.16.47/dist/katex.min.js",
    sri = "sha384-CwjPRVHTvLiMBFjEoij+QZViMV5rhTOIp7CJzl24JEqpRDA1sJFHVXXLURktbYYp",
    global = "katex",
    css = CDN .. "katex@0.16.47/dist/katex.min.css",
    css_sri = "sha384-nH0MfJ44wi1dd7w6jinlyBgljjS8EJAh2JBoRad8a3VDw2K69vfaaqm4WnR+gXtA",
    -- CSS が相対パスで読むフォントの場所 (CSP の font-src に入れる)
    fonts = CDN .. "katex@0.16.47/dist/fonts/",
  },
  -- 図。GitLab も mermaid で、HTML の .js-render-mermaid をブラウザ側で描く
  mermaid = {
    url = CDN .. "mermaid@11.17.2/dist/mermaid.min.js",
    sri = "sha384-EOXBFmc3gx5mb+vn0vPvvGqACToJD24hhacX5Yx+8NUUQrHIle/Qi5Bg9o3zKwW2",
    global = "mermaid",
  },
}
