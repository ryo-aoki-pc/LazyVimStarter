// GitLab プレビューのページ。Neovim (lua/config/gitlab_preview) から SSE で届く内容を描く。
//  - mode "api":      GitLab の Markdown API が描いた HTML。GitLab のフロントエンドがブラウザで行う
//                      処理 (数式・mermaid・遅延読み込みの画像) だけをここで行う
//  - mode "fallback": GitLab に送れないとき。原文を markdown-it で描き、GLFM の一部だけを真似る
// ライブラリは必要になったときに jsDelivr から読む (版と SRI は libs.lua。CSP もそこから作られる)。
'use strict';

(() => {
  const BASE = new URL('./', location.href); // http://127.0.0.1:PORT/<token>/ (token を書き込まない)
  const LIBS = JSON.parse(document.getElementById('gp-libs').textContent);
  const header = document.getElementById('gp-header');
  const fileEl = document.getElementById('gp-file');
  const modeEl = document.getElementById('gp-mode');
  const banner = document.getElementById('gp-banner');
  const content = document.getElementById('gp-content');
  const dark = window.matchMedia('(prefers-color-scheme: dark)');

  // ---- ライブラリ ---------------------------------------------------------------

  const loading = new Map();

  function addStyle(url, sri) {
    return new Promise((resolve, reject) => {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = url;
      link.integrity = sri;
      link.crossOrigin = 'anonymous';
      link.onload = resolve;
      link.onerror = () => reject(new Error(url));
      document.head.appendChild(link);
    });
  }

  function load(name) {
    if (!loading.has(name)) {
      const lib = LIBS[name];
      const script = new Promise((resolve, reject) => {
        const s = document.createElement('script');
        s.src = lib.url;
        s.integrity = lib.sri;
        s.crossOrigin = 'anonymous';
        s.onload = () => (window[lib.global] ? resolve(window[lib.global]) : reject(new Error(name)));
        s.onerror = () => reject(new Error(lib.url));
        document.head.appendChild(s);
      });
      const all = lib.css ? Promise.all([script, addStyle(lib.css, lib.css_sri)]).then(([v]) => v) : script;
      // 読めなかったら覚えない (オフラインから戻ったら、次の描画で読み直す)
      loading.set(
        name,
        all.catch((e) => {
          loading.delete(name);
          throw e;
        }),
      );
    }
    return loading.get(name);
  }

  // ---- 接続とバナー ---------------------------------------------------------------

  let connMsg = ''; // 接続の状態 (こちらを優先して出す)
  let renderMsg = ''; // 近似表示の理由など

  function updateBanner() {
    const text = connMsg || renderMsg;
    banner.textContent = text;
    banner.hidden = !text;
    banner.dataset.kind = connMsg ? 'conn' : 'render';
  }

  let last = null; // 最後の render
  let lastScroll = null; // 最後の scroll
  let stopped = null; // "stop" | "exit" | null
  let dropTimer = 0;

  const es = new EventSource('_/events');
  es.addEventListener('open', () => {
    clearTimeout(dropTimer);
    stopped = null;
    connMsg = '';
    updateBanner();
  });
  es.addEventListener('error', () => {
    if (stopped) return;
    // 再接続はブラウザが自動で行う。すぐに戻ることが多いので、少し待ってから出す
    clearTimeout(dropTimer);
    dropTimer = setTimeout(() => {
      connMsg = 'Neovim との接続が切れた。再接続を待っている…';
      updateBanner();
    }, 1500);
  });
  es.addEventListener('stop', (e) => {
    const m = JSON.parse(e.data);
    stopped = m.reason;
    clearTimeout(dropTimer);
    if (m.reason === 'exit') {
      es.close();
      connMsg = 'Neovim が終了した';
    } else {
      // 再接続は続ける (同じ Neovim で開き直すと、このタブがそのまま戻る)
      connMsg = 'プレビューを止めた (:GitLabPreview で再開する)';
    }
    updateBanner();
  });
  es.addEventListener('render', (e) => {
    render(JSON.parse(e.data));
  });
  es.addEventListener('scroll', (e) => {
    lastScroll = JSON.parse(e.data);
    syncScroll();
  });

  // ---- 描画 ---------------------------------------------------------------------

  let gen = 0; // 描画の世代。非同期の処理の途中で次の描画が来たら、古いほうは捨てる

  async function render(m) {
    const my = ++gen;
    last = m;
    fileEl.textContent = m.file || '';
    document.title = (m.file ? m.file + ' — ' : '') + 'GitLab プレビュー';
    if (m.mode === 'api') {
      modeEl.textContent = 'GitLab: ' + m.gitlab.host + (m.gitlab.project ? ' / ' + m.gitlab.project : '');
    } else {
      modeEl.textContent = '近似表示';
    }
    modeEl.dataset.mode = m.mode;

    // <template> の中身は画像を読み込まないので、URL を書き換えてから文書に入れる
    const tpl = document.createElement('template');
    if (m.mode === 'api') {
      tpl.innerHTML = m.html;
      renderMsg = '';
    } else {
      renderMsg = '近似表示: ' + m.reason + '。GitLab の表示とは異なる部分がある';
      try {
        const html = await renderLocal(m.markdown);
        if (my !== gen) return;
        tpl.innerHTML = html;
        glfm(tpl.content);
      } catch (err) {
        if (my !== gen) return;
        const pre = document.createElement('pre');
        pre.className = 'gp-raw';
        pre.textContent = m.markdown;
        tpl.content.replaceChildren(pre);
        renderMsg = '描画用のライブラリ (cdn.jsdelivr.net) を読み込めないため、原文を表示している (' + m.reason + ')';
      }
    }
    updateBanner();
    rewriteUrls(tpl.content, m);

    // 開いていた <details> は、描き直しても開いたままにする
    const open = Array.from(content.querySelectorAll('details'), (d) => d.open);
    content.replaceChildren(tpl.content);
    content.querySelectorAll('details').forEach((d, i) => {
      if (open[i]) d.open = true;
    });
    buildMap();
    syncScroll();

    await renderMath(my);
    await renderMermaid(my);
    if (my !== gen) return;
    buildMap();
    syncScroll();
  }

  // ---- URL の書き換え -------------------------------------------------------------
  // GitLab は、リポジトリの中への相対リンクを既定のブランチの URL (/<project>/-/raw/main/…) に書き換え、
  // 書き換える前の値を data-canonical-src に残す。画像や動画は、その値を .md の場所から解決し直して
  // 手元のファイル (push していない画像も) を見せる。ほかのページへのリンクは GitLab の URL のまま。

  const SCHEME = /^[a-z][a-z0-9+.-]*:/i;

  function isRelative(v) {
    return !!v && !SCHEME.test(v) && !v.startsWith('//') && !v.startsWith('#');
  }

  function dirUrl(dir) {
    const enc = dir.split('/').filter(Boolean).map(encodeURIComponent).join('/');
    return new URL(enc ? enc + '/' : '', BASE);
  }

  // リポジトリの中の値を、ローカルのサーバーの URL にする。"/" で始まるものはルートから
  function toLocal(v, dir) {
    try {
      if (v.startsWith('/')) return new URL(v.replace(/^\/+/, ''), BASE).href;
      return new URL(v, dirUrl(dir)).href;
    } catch {
      return v;
    }
  }

  // 古い GitLab (data-canonical-src を残さない版) の予備: /<project>/-/raw|blob|tree/<ref>/<path> の <path>
  function repoPath(v, gl) {
    if (!gl || !gl.project) return null;
    let p = v;
    if (p.startsWith(gl.origin)) p = p.slice(gl.origin.length);
    const prefix = (gl.path || '') + '/' + gl.project + '/-/';
    if (!p.startsWith(prefix)) return null;
    const m = /^(?:raw|blob|tree)\/[^/]+\/([^?#]*)/.exec(p.slice(prefix.length));
    return m ? m[1] : null;
  }

  function mediaUrl(v, canon, m) {
    if (v.startsWith('data:')) return v; // GitLab の遅延読み込みの仮の画像 (本物は data-src)
    const gl = m.mode === 'api' ? m.gitlab : null;
    if (canon && isRelative(canon) && !canon.startsWith('/uploads/')) return toLocal(canon, m.dir);
    if (gl) {
      const rp = repoPath(v, gl);
      if (rp !== null) return toLocal(rp, m.dir);
      if (v.startsWith('/') && !v.startsWith('//')) return gl.origin + v; // /uploads/ などは GitLab から
      return v;
    }
    return isRelative(v) ? toLocal(v, m.dir) : v;
  }

  function linkUrl(v, m) {
    const gl = m.mode === 'api' ? m.gitlab : null;
    if (gl) return v.startsWith('/') && !v.startsWith('//') ? gl.origin + v : v;
    return isRelative(v) ? toLocal(v, m.dir) : v;
  }

  function rewriteUrls(root, m) {
    for (const el of root.querySelectorAll('img, video, audio, source')) {
      const canon = el.getAttribute('data-canonical-src');
      for (const attr of ['src', 'data-src']) {
        const v = el.getAttribute(attr);
        if (v) el.setAttribute(attr, mediaUrl(v, canon, m));
      }
    }
    // GitLab は画像を遅延読み込みにする (src は仮の画像で、本物は data-src)。ここではすぐに読む
    for (const el of root.querySelectorAll('[data-src]')) {
      el.setAttribute('src', el.getAttribute('data-src'));
      el.removeAttribute('data-src');
      el.classList.remove('lazy');
    }
    // 画像を包むリンク (クリックで原寸を開く) は、書き換えた画像そのものに向ける
    for (const a of root.querySelectorAll('a.no-attachment-icon')) {
      const media = a.querySelector('img[src], video[src]');
      if (media) a.setAttribute('href', media.getAttribute('src'));
    }
    for (const a of root.querySelectorAll('a[href]')) {
      const v = a.getAttribute('href');
      if (v.startsWith('#')) continue;
      a.setAttribute('href', linkUrl(v, m));
      a.target = '_blank'; // プレビューのタブは残す
      a.rel = 'noopener noreferrer';
    }
  }

  // ---- 近似表示 (GitLab に送れないとき) -----------------------------------------------

  let md = null;

  async function markdown() {
    if (md) return md;
    const [markdownit, footnote] = await Promise.all([load('markdownit'), load('footnote')]);
    const inst = markdownit({ html: true, linkify: true });
    inst.use(footnote);
    // ブロックに GitLab と同じ形の data-sourcepos を付ける (スクロールの同期に使う)
    inst.core.ruler.push('gp_sourcepos', (state) => {
      for (const t of state.tokens) {
        if (t.map && (t.nesting === 1 || ['fence', 'code_block', 'hr', 'html_block'].includes(t.type))) {
          t.attrSet('data-sourcepos', t.map[0] + 1 + ':1-' + t.map[1] + ':1');
        }
      }
    });
    const fence = inst.renderer.rules.fence;
    inst.renderer.rules.fence = (tokens, idx, options, env, self) => {
      const t = tokens[idx];
      const lang = (t.info || '').trim().split(/\s+/)[0];
      const pos = t.attrGet('data-sourcepos');
      const at = pos ? ' data-sourcepos="' + pos + '"' : '';
      const body = inst.utils.escapeHtml(t.content);
      // GitLab の HTML と同じ目印にして、下の数式・mermaid の処理をそのまま通す
      if (lang === 'mermaid') {
        return '<pre data-canonical-lang="mermaid"' + at + '><code class="js-render-mermaid">' + body + '</code></pre>\n';
      }
      if (lang === 'math') {
        return '<pre class="js-render-math" data-math-style="display"' + at + '><code>' + body + '</code></pre>\n';
      }
      return fence(tokens, idx, options, env, self);
    };
    md = inst;
    return md;
  }

  // 先頭の front matter (--- / +++ / ;;;) を、行数を変えずにコードブロックへ置き換える
  function frontMatter(src) {
    const head = /^(---|\+\+\+|;;;)[ \t]*\r?\n/.exec(src);
    if (!head) return src;
    const lines = src.split('\n');
    for (let i = 1; i < lines.length; i++) {
      if (lines[i].replace(/[ \t\r]+$/, '') === head[1]) {
        lines[0] = '~~~~' + { '---': 'yaml', '+++': 'toml', ';;;': 'json' }[head[1]];
        lines[i] = '~~~~';
        return lines.join('\n');
      }
    }
    return src;
  }

  async function renderLocal(src) {
    return (await markdown()).render(frontMatter(src));
  }

  const ALERTS = { note: 'Note', tip: 'Tip', important: 'Important', warning: 'Warning', caution: 'Caution' };
  const BLOCK = /^(UL|OL|P|PRE|BLOCKQUOTE|DIV|TABLE|DL)$/;

  // 見出しの id を GitLab の規則で付ける (小文字にし、記号を消し、空白を - にし、重複には -1, -2 …)
  function headingIds(root) {
    const used = new Map();
    const list = [];
    for (const h of root.querySelectorAll('h1, h2, h3, h4, h5, h6')) {
      const text = h.textContent.trim();
      let id = text
        .toLowerCase()
        .replace(/[^\p{L}\p{M}\p{N}\p{Pc}\- ]/gu, '')
        .replace(/ /g, '-')
        .replace(/-{2,}/g, '-');
      const n = used.get(id);
      used.set(id, n === undefined ? 0 : n + 1);
      if (n !== undefined) id = id + '-' + (n + 1);
      const a = document.createElement('a');
      a.className = 'anchor';
      a.href = '#' + id;
      a.id = 'user-content-' + id;
      a.setAttribute('aria-hidden', 'true');
      h.prepend(a);
      list.push({ level: Number(h.tagName[1]), id, text });
    }
    return list;
  }

  function toc(headings) {
    const top = document.createElement('ul');
    top.className = 'section-nav';
    const stack = [{ level: 0, ul: top }];
    for (const h of headings) {
      while (stack.length > 1 && stack[stack.length - 1].level >= h.level) stack.pop();
      const li = document.createElement('li');
      const a = document.createElement('a');
      a.href = '#' + h.id;
      a.textContent = h.text;
      li.appendChild(a);
      stack[stack.length - 1].ul.appendChild(li);
      const ul = document.createElement('ul');
      li.appendChild(ul);
      stack.push({ level: h.level, ul });
    }
    top.querySelectorAll('ul:empty').forEach((u) => u.remove());
    return top;
  }

  // li の中で、チェックボックスの記法が入っている要素 (緩いリストなら先頭の <p>)
  function taskHost(li) {
    const fe = li.firstElementChild;
    if (fe && fe.tagName === 'P') {
      for (let n = li.firstChild; n && n !== fe; n = n.nextSibling) {
        if (n.nodeType !== Node.TEXT_NODE || n.nodeValue.trim()) return li;
      }
      return fe;
    }
    return li;
  }

  function glfm(root) {
    const headings = headingIds(root);

    for (const p of root.querySelectorAll('p')) {
      const t = p.textContent.trim();
      if (/^(\[\[_?toc_?\]\]|\[toc\])$/i.test(t)) {
        // [[_TOC_]] は markdown-it では [[<em>TOC</em>]] になるので、文字だけで見る
        p.replaceWith(toc(headings));
      } else if (t.length > 4 && t.startsWith('$$') && t.endsWith('$$')) {
        const pre = document.createElement('pre');
        pre.className = 'js-render-math';
        pre.setAttribute('data-math-style', 'display');
        const pos = p.getAttribute('data-sourcepos');
        if (pos) pre.setAttribute('data-sourcepos', pos);
        pre.textContent = t.slice(2, -2);
        p.replaceWith(pre);
      }
    }

    // > [!note] タイトル → アラート
    for (const bq of root.querySelectorAll('blockquote')) {
      const p = bq.firstElementChild;
      const first = p && p.tagName === 'P' ? p.firstChild : null;
      if (!first || first.nodeType !== Node.TEXT_NODE) continue;
      const m = /^\[!(note|tip|important|warning|caution)\][ \t]*([^\n]*)\n?/i.exec(first.nodeValue);
      if (!m) continue;
      const type = m[1].toLowerCase();
      first.nodeValue = first.nodeValue.slice(m[0].length);
      const div = document.createElement('div');
      div.className = 'markdown-alert markdown-alert-' + type;
      const pos = bq.getAttribute('data-sourcepos');
      if (pos) div.setAttribute('data-sourcepos', pos);
      const title = document.createElement('p');
      title.className = 'markdown-alert-title';
      title.textContent = m[2].trim() || ALERTS[type];
      if (!p.textContent.trim() && !p.querySelector('img')) p.remove();
      div.append(title, ...bq.childNodes);
      bq.replaceWith(div);
    }

    // - [ ] / - [x] / - [~] (GitLab の「対象外」)
    for (const li of root.querySelectorAll('li')) {
      const host = taskHost(li);
      const first = host.firstChild;
      if (!first || first.nodeType !== Node.TEXT_NODE) continue;
      const m = /^\[([ xX~])\][ \t]+/.exec(first.nodeValue);
      if (!m) continue;
      first.nodeValue = first.nodeValue.slice(m[0].length);
      const box = document.createElement('input');
      box.type = 'checkbox';
      box.className = 'task-list-item-checkbox';
      box.disabled = true;
      box.checked = m[1] === 'x' || m[1] === 'X';
      li.classList.add('task-list-item');
      if (m[1] === '~') {
        li.classList.add('inapplicable');
        box.setAttribute('data-inapplicable', '');
        const s = document.createElement('s');
        let n = host.firstChild;
        while (n && !(n.nodeType === Node.ELEMENT_NODE && BLOCK.test(n.nodeName))) {
          const next = n.nextSibling;
          s.appendChild(n);
          n = next;
        }
        host.insertBefore(s, n);
      }
      host.prepend(box, ' ');
      if (li.parentElement) li.parentElement.classList.add('task-list');
    }

    // $`…`$ → 文中の数式 (markdown-it では $<code>…</code>$ になる)
    for (const code of root.querySelectorAll('code')) {
      if (code.closest('pre')) continue;
      const prev = code.previousSibling;
      const next = code.nextSibling;
      if (
        prev &&
        next &&
        prev.nodeType === Node.TEXT_NODE &&
        next.nodeType === Node.TEXT_NODE &&
        prev.nodeValue.endsWith('$') &&
        next.nodeValue.startsWith('$')
      ) {
        prev.nodeValue = prev.nodeValue.slice(0, -1);
        next.nodeValue = next.nodeValue.slice(1);
        code.classList.add('js-render-math');
        code.setAttribute('data-math-style', 'inline');
      }
    }
  }

  // ---- 数式と図 -------------------------------------------------------------------

  function sourcepos(el) {
    if (el.hasAttribute('data-sourcepos')) return el.getAttribute('data-sourcepos');
    const inner = el.querySelector('[data-sourcepos]');
    return inner ? inner.getAttribute('data-sourcepos') : null;
  }

  async function renderMath(my) {
    const els = Array.from(content.querySelectorAll('.js-render-math'));
    if (!els.length) return;
    let katex;
    try {
      katex = await load('katex');
    } catch {
      return; // 読めなければ TeX のまま見せる
    }
    if (my !== gen) return;
    for (const el of els) {
      if (!el.isConnected) continue;
      const display = el.getAttribute('data-math-style') === 'display';
      const box = display ? el.closest('.markdown-code-block') || el.closest('pre') || el : el;
      const out = document.createElement(display ? 'div' : 'span');
      out.className = display ? 'gp-math-display' : 'gp-math-inline';
      const pos = sourcepos(box);
      if (pos) out.setAttribute('data-sourcepos', pos);
      try {
        // GitLab と同じく、巨大なサイズやマクロの展開は抑える
        katex.render(el.textContent, out, { displayMode: display, throwOnError: false, maxSize: 20, maxExpand: 1000 });
      } catch {
        out.textContent = el.textContent;
        out.classList.add('gp-error');
      }
      box.replaceWith(out);
    }
  }

  let mermaidTheme = null;
  let mermaidSeq = 0;
  const svgCache = new Map();

  async function renderMermaid(my) {
    const codes = Array.from(content.querySelectorAll('.js-render-mermaid'));
    if (!codes.length) return;
    let mermaid;
    try {
      mermaid = await load('mermaid');
    } catch {
      return; // 読めなければ図の原文を見せる
    }
    if (my !== gen) return;
    const theme = dark.matches ? 'dark' : 'default';
    if (theme !== mermaidTheme) {
      mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme });
      mermaidTheme = theme;
    }
    for (const code of codes) {
      if (my !== gen) return;
      if (!code.isConnected) continue;
      const src = code.textContent;
      const box = code.closest('.markdown-code-block') || code.closest('pre') || code;
      const out = document.createElement('div');
      out.className = 'gp-mermaid';
      const pos = sourcepos(box);
      if (pos) out.setAttribute('data-sourcepos', pos);
      const key = theme + '\n' + src;
      const id = 'gp-mermaid-' + ++mermaidSeq;
      try {
        let svg = svgCache.get(key);
        if (!svg) {
          ({ svg } = await mermaid.render(id, src));
          if (svgCache.size > 100) svgCache.clear();
          svgCache.set(key, svg);
        }
        if (my !== gen) return;
        out.innerHTML = svg;
      } catch (e) {
        document.getElementById('d' + id)?.remove(); // 失敗したときに mermaid が残す作業用の要素
        out.className = 'gp-error';
        out.textContent = 'mermaid: ' + (e && e.message ? e.message : String(e));
      }
      if (box.isConnected) box.replaceWith(out);
    }
  }

  // OS のライト / ダークが切り替わったら、図の配色ごと描き直す
  dark.addEventListener('change', () => {
    if (last) render(last);
  });

  // ---- スクロールの同期 -------------------------------------------------------------
  // GitLab の HTML はブロックに data-sourcepos (開始行:列-終了行:列) を持つ。カーソルの行を含む要素を探し、
  // 要素の中は行で按分する。カーソルが Neovim の窓のどの高さにあるか (ratio) にも合わせる。

  let map = [];

  function buildMap() {
    map = [];
    for (const el of content.querySelectorAll('[data-sourcepos]')) {
      const m = /^(\d+):\d+-(\d+):\d+/.exec(el.getAttribute('data-sourcepos'));
      if (m && el.getClientRects().length) map.push({ start: Number(m[1]), end: Number(m[2]), el });
    }
    // 脚注の定義は文書の末尾に描かれるので、開始行で並べ直す (同じ開始行なら文書の順 = 内側の要素が後ろ)
    map.sort((a, b) => a.start - b.start);
  }

  function topOf(el) {
    return el.getBoundingClientRect().top + window.scrollY;
  }

  function syncScroll() {
    const s = lastScroll;
    if (!s || !last) return;
    const head = header.offsetHeight;
    let y;
    if (map.length) {
      let lo = 0;
      let hi = map.length - 1;
      let i = -1;
      while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (map[mid].start <= s.line) {
          i = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      if (i < 0) {
        y = 0;
      } else {
        const cur = map[i];
        const top = topOf(cur.el);
        const height = cur.el.getBoundingClientRect().height;
        if (s.line <= cur.end) {
          y = top + height * ((s.line - cur.start) / Math.max(1, cur.end - cur.start + 1));
        } else {
          const next = map[i + 1];
          const bottom = top + height;
          y = next ? bottom + (topOf(next.el) - bottom) * ((s.line - cur.end) / Math.max(1, next.start - cur.end)) : bottom;
        }
      }
    } else {
      // data-sourcepos が無い (古い GitLab など) ときは、全体の行数との比で動かす
      y = document.documentElement.scrollHeight * ((s.line - 1) / Math.max(1, s.lines - 1));
    }
    window.scrollTo({ top: Math.max(0, y - head - s.ratio * (window.innerHeight - head)), behavior: 'auto' });
  }

  // 画像が読み込まれると高さが変わるので、合わせ直す
  let syncQueued = false;
  content.addEventListener(
    'load',
    () => {
      if (syncQueued) return;
      syncQueued = true;
      requestAnimationFrame(() => {
        syncQueued = false;
        syncScroll();
      });
    },
    true,
  );

  // ---- ページ内のリンク -------------------------------------------------------------
  // GitLab は見出しなどの id に user-content- を付ける ([[_TOC_]] や脚注の #… はそちらを指す)
  content.addEventListener('click', (e) => {
    const a = e.target.closest('a[href^="#"]');
    if (!a) return;
    let id = a.getAttribute('href').slice(1);
    try {
      id = decodeURIComponent(id);
    } catch {
      // そのまま使う
    }
    const target = document.getElementById('user-content-' + id) || document.getElementById(id);
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ block: 'start' });
    }
  });
})();
