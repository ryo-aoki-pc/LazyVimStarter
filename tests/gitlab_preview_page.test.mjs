// ページ側の配線を、ローカル HTTP / SSE と実ブラウザで確かめる。
// PLAYWRIGHT_MODULE は既存の playwright の導入先を指定できる。追加の npm install は行わない。
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import test from 'node:test';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright'));
} catch {
  // ブラウザ試験の依存が無い環境では、未実施と分かるように skip する。
}
const browserPath = [
  process.env.EDGE_BIN,
  process.env.CHROME_BIN,
  process.platform === 'win32' && join(process.env['ProgramFiles(x86)'] || '', 'Microsoft/Edge/Application/msedge.exe'),
  process.platform === 'win32' && join(process.env.ProgramFiles || '', 'Google/Chrome/Application/chrome.exe'),
  chromium && chromium.executablePath(),
].find((path) => path && existsSync(path));
const pageDir = new URL('../lua/config/gitlab_preview/page/', import.meta.url);
const source = Object.fromEntries(await Promise.all(
  ['index.html', 'preview.js', 'preview.css', 'fallback.css'].map(async (name) => [name, await readFile(new URL(name, pageDir), 'utf8')]),
));

function assets(id = 'fixture-v1') {
  return {
    id,
    version: '19.5.1',
    styles: {
      light: ['application.css', 'page.css', 'tailwind.css', 'fonts.css', 'white.css'],
      dark: ['application_dark.css', 'page.css', 'tailwind.css', 'fonts.css', 'dark.css'],
    },
    sprite: 'icons.svg',
  };
}

function payload(html, extra = {}) {
  return {
    mode: 'api', file: 'docs/試験.md', dir: 'docs/', html,
    gitlab: { origin: 'https://gitlab.example.test', host: 'gitlab.example.test', path: '', project: 'group/project' },
    assets_id: 'fixture-v1', ...extra,
  };
}

function css(name) {
  if (name === 'application.css' || name === 'application_dark.css') {
    const dark = name.includes('_dark');
    return `:root { --gl-background-color-default:${dark ? '#111827' : '#ffffff'}; --gl-text-color-default:${dark ? '#eeeeee' : '#222222'}; --gl-text-color-subtle:#777; --gl-border-color-default:#888; --gl-background-color-subtle:${dark ? '#1f2937' : '#fafafa'}; } .md p {margin-bottom:17px} .md td {padding:10px 16px} .md h1 {font-size:31px}`;
  }
  if (name === 'page.css') return '.file-holder .file-content.md {line-height:1.5;font-size:16px}';
  if (name === 'tailwind.css') return '.gl-fixture {padding:3px}';
  if (name === 'fonts.css') return 'body {font-family:sans-serif}';
  if (name === 'white.css') return '.code-syntax-highlight-theme {background:#fafafa} .code-syntax-highlight-theme .k {color:rgb(10,20,30)}';
  if (name === 'dark.css') return '.code-syntax-highlight-theme {background:#282a36} .code-syntax-highlight-theme .k {color:rgb(210,220,230)}';
  return '';
}

async function harness() {
  const fixtures = new Map();
  let serial = 0;
  const server = createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const [, id, ...parts] = url.pathname.split('/');
    const fixture = fixtures.get(id);
    if (!fixture) return res.writeHead(404).end();
    fixture.requests.push(parts.join('/'));
    const rel = parts.join('/');
    if (!rel) {
      const libs = Object.fromEntries(['mermaid', 'markdownit', 'footnote'].map((name) => [name, {
        url: fixture.url + '_/' + name + '.js', sri: '', global: name,
      }]));
      const html = source['index.html']
        .replace('{{LIBS}}', JSON.stringify(libs))
        .replace('{{CONFIG}}', JSON.stringify(fixture.config).replaceAll('<', '\\u003c'));
      return res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' }).end(html);
    }
    if (rel === '_/events') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-store' });
      fixture.clients.add(res);
      req.on('close', () => fixture.clients.delete(res));
      res.write('event: render\ndata: ' + JSON.stringify(fixture.render) + '\n\n');
      return;
    }
    if (rel.startsWith('_/assets/')) {
      const name = parts.at(-1);
      if (fixture.failStyle && name === fixture.failStyle) return res.writeHead(404).end();
      if (name === 'icons.svg') return res.writeHead(200, { 'Content-Type': 'image/svg+xml', 'Content-Security-Policy': 'sandbox' }).end('<svg xmlns="http://www.w3.org/2000/svg"><symbol id="link"><path d="M0 0h10v10z"/></symbol></svg>');
      return res.writeHead(200, { 'Content-Type': 'text/css', 'Content-Security-Policy': 'sandbox' }).end(css(name));
    }
    const name = rel.replace(/^_\//, '');
    if (Object.hasOwn(source, name)) {
      return res.writeHead(200, { 'Content-Type': name.endsWith('.css') ? 'text/css' : 'text/javascript' }).end(source[name]);
    }
    if (name === 'mermaid.js') return res.writeHead(200, { 'Content-Type': 'text/javascript' }).end(`window.mermaid={initialize(o){this.theme=o.theme},async render(id,src){return {svg:'<svg><text>'+this.theme+'</text></svg>'}}};`);
    // パーサー自体は対象外。外部描画器から返る HTML と、ページの GLFM 後処理を分けて確かめる。
    if (name === 'markdownit.js') return res.writeHead(200, { 'Content-Type': 'text/javascript' }).end(`window.markdownit=()=>({use(){},core:{ruler:{push(){}}},renderer:{rules:{fence(){}}},utils:{escapeHtml(s){return s}},render(){return ${JSON.stringify(fixture.localHtml || '<p>近似の本文</p>')}}});`);
    if (name === 'footnote.js') return res.writeHead(200, { 'Content-Type': 'text/javascript' }).end('window.footnote=()=>{};');
    res.writeHead(404).end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return {
    fixture(options = {}) {
      const id = 'case-' + ++serial;
      const fixture = {
        url: `http://127.0.0.1:${server.address().port}/${id}/`,
        config: { appearance: { theme: 'system', width: 'fluid' }, assets: assets(), notice: '', ...options.config },
        render: options.render || payload('<h1 data-sourcepos="1:1-1:1">見出し</h1><p>本文</p><table><tr><td>セル</td></tr></table><pre class="highlight"><code><span class="k">const</span></code></pre>'),
        requests: [], clients: new Set(), failStyle: options.failStyle, localHtml: options.localHtml,
        send(event, data) {
          for (const client of this.clients) client.write('event: ' + event + '\ndata: ' + JSON.stringify(data) + '\n\n');
        },
      };
      fixtures.set(id, fixture);
      return fixture;
    },
    async close() {
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve));
    },
  };
}

async function openPage(browser, fixture, options = {}) {
  const context = await browser.newContext({ viewport: { width: 2000, height: 900 }, colorScheme: 'light', ...options });
  await context.route('**/*', (route) => route.request().url().startsWith(fixture.url) ? route.continue() : route.abort());
  const page = await context.newPage();
  page.setDefaultTimeout(5000);
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto(fixture.url);
  await page.waitForFunction(() => document.querySelector('#gp-mode').textContent !== '');
  return { page, context, errors };
}

test('GitLab プレビューのページ', { skip: !chromium || !browserPath ? 'Playwright と Edge / Chromium が必要' : false }, async (t) => {
  const browser = await chromium.launch({ executablePath: browserPath, headless: true });
  const http = await harness();
  t.after(async () => { await browser.close(); await http.close(); });

  await t.test('公式スタイル・テーマ・全幅と固定幅を切り替える', async () => {
    const fixture = http.fixture();
    const { page, context, errors } = await openPage(browser, fixture);
    await page.waitForFunction(() => document.documentElement.dataset.style === 'official');
    assert.equal(await page.locator('#gp-page > .file-content.js-markup-content.md').count(), 1);
    assert.equal(await page.locator('#gp-content p').evaluate((el) => getComputedStyle(el).marginBottom), '17px');
    assert.equal(await page.locator('#gp-content td').evaluate((el) => getComputedStyle(el).paddingTop), '10px');
    assert.equal(await page.evaluate(() => document.body.classList.contains('code-syntax-highlight-theme')), false);
    assert.equal(await page.locator('.highlight').evaluate((el) => el.classList.contains('code-syntax-highlight-theme')), true);
    assert.equal(fixture.requests.includes('_/fallback.css'), false);
    assert.ok(await page.locator('#gp-page').evaluate((el) => el.getBoundingClientRect().width) > 1600);
    await page.selectOption('#gp-width', 'fixed');
    assert.equal(await page.locator('#gp-page').evaluate((el) => el.getBoundingClientRect().width), 1600);
    await page.evaluate(() => {
      window.originalTable = document.querySelector('#gp-content table');
      const panel = document.createElement('div');
      panel.id = 'table-panel';
      panel.className = 'md';
      panel.append(window.originalTable);
      panel.style.background = 'var(--gl-background-color-default)';
      document.body.append(panel);
    });
    await page.selectOption('#gp-theme', 'dark');
    await page.waitForFunction(() => getComputedStyle(document.body).backgroundColor === 'rgb(17, 24, 39)');
    assert.equal(await page.locator('#table-panel').evaluate((el) => getComputedStyle(el).backgroundColor), 'rgb(17, 24, 39)');
    assert.equal(await page.locator('#table-panel td').evaluate((el) => getComputedStyle(el).paddingTop), '10px');
    assert.equal(await page.evaluate(() => window.originalTable === document.querySelector('#table-panel table')), true);
    assert.equal(await page.locator('.highlight .k').evaluate((el) => getComputedStyle(el).color), 'rgb(210, 220, 230)');
    assert.equal(await page.evaluate(() => [...document.querySelectorAll('link[rel=stylesheet]')].filter((el) => el.media === 'all' && el.href.includes('/_/assets/')).length), 5);
    await page.selectOption('#gp-theme', 'light');
    await page.waitForFunction(() => getComputedStyle(document.body).backgroundColor === 'rgb(255, 255, 255)');
    await page.emulateMedia({ colorScheme: 'dark' });
    assert.equal(await page.evaluate(() => document.documentElement.classList.contains('gl-dark')), false);
    await page.selectOption('#gp-theme', 'system');
    await page.waitForFunction(() => document.documentElement.classList.contains('gl-dark'));
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('未導入の案内と描画方式を分け、従来のスタイルも手動配色に従う', async () => {
    const fixture = http.fixture({ config: { assets: null, notice: '公式スタイル未導入。:GitLabPreviewInstall で導入する' }, render: payload('<h1>見出し</h1>', { assets_id: false }) });
    const { page, context, errors } = await openPage(browser, fixture);
    await page.waitForSelector('#gp-fallback-style', { state: 'attached' });
    assert.match(await page.locator('#gp-mode').textContent(), /^GitLab:/);
    assert.match(await page.locator('#gp-banner').textContent(), /公式スタイル未導入/);
    await page.selectOption('#gp-theme', 'dark');
    await page.waitForFunction(() => getComputedStyle(document.body).backgroundColor === 'rgb(31, 30, 36)');
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.selectOption('#gp-theme', 'light');
    await page.waitForFunction(() => getComputedStyle(document.body).backgroundColor === 'rgb(255, 255, 255)');
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('公式 CSS の失敗は本文を維持して従来のスタイルへ退避する', async () => {
    const fixture = http.fixture({ failStyle: 'page.css' });
    const { page, context, errors } = await openPage(browser, fixture);
    await page.waitForFunction(() => document.documentElement.dataset.style === 'fallback');
    assert.match(await page.locator('#gp-banner').textContent(), /公式スタイルを読み込めない/);
    assert.match(await page.locator('#gp-banner').textContent(), /:GitLabPreviewInstall/);
    assert.match(await page.locator('#gp-content').textContent(), /見出し/);
    assert.equal(await page.evaluate(() => [...document.querySelectorAll('link')].some((el) => el.href.includes('/_/assets/') && el.media === 'all')), false);
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('GitLab のアイコンだけを導入済み sprite へ書き換える', async () => {
    const fixture = http.fixture({ render: payload('<svg><use id="official-icon" href="https://gitlab.example.test/assets/icons-abc123.svg#link"></use><use id="user-icon" href="/uploads/user.svg#link"></use><use id="foreign-icon" href="https://example.test/assets/icons-abc123.svg#link"></use></svg>') });
    const { page, context, errors } = await openPage(browser, fixture);
    assert.equal(await page.locator('#official-icon').getAttribute('href'), fixture.url + '_/assets/fixture-v1/icons.svg#link');
    await page.waitForFunction(() => document.querySelector('#official-icon').getBBox().width === 10);
    assert.equal(await page.locator('#user-icon').getAttribute('href'), '/uploads/user.svg#link');
    assert.equal(await page.locator('#foreign-icon').getAttribute('href'), 'https://example.test/assets/icons-abc123.svg#link');
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('近似表示の目次・アラート・対象外タスクを保つ', async () => {
    const fixture = http.fixture({
      render: { mode: 'fallback', file: 'docs/試験.md', dir: 'docs/', markdown: 'パーサーへの入力', reason: 'GitLab に接続できない', assets_id: 'fixture-v1' },
      localHtml: '<h1>題</h1><p>[[_TOC_]]</p><blockquote><p>[!note] 注意\n内容</p></blockquote><ul><li>[~] 対象外</li></ul>',
    });
    const { page, context, errors } = await openPage(browser, fixture);
    await page.waitForSelector('.section-nav');
    assert.equal(await page.locator('.section-nav a').textContent(), '題');
    assert.equal(await page.locator('.markdown-alert-title').textContent(), '注意');
    assert.equal(await page.locator('li.inapplicable input').count(), 1);
    assert.match(await page.locator('#gp-banner').textContent(), /GitLab に接続できない/);
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('Mermaid の配色だけ更新し、本文の要素を置き換えない', async () => {
    const fixture = http.fixture({ render: payload('<details open><summary>内容</summary><p>本文</p></details><pre data-sourcepos="2:1-5:1"><code class="js-render-mermaid">graph TD; A--&gt;B</code></pre>') });
    const { page, context, errors } = await openPage(browser, fixture);
    await page.waitForSelector('.gp-mermaid svg');
    await page.evaluate(() => { window.originalDetails = document.querySelector('details'); });
    await page.selectOption('#gp-theme', 'dark');
    await page.waitForFunction(() => document.querySelector('.gp-mermaid').textContent === 'dark');
    assert.equal(await page.evaluate(() => window.originalDetails === document.querySelector('details') && window.originalDetails.open), true);
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('資産版変更と同版の明示通知で再読込し、操作した配色と幅を保つ', async () => {
    const fixture = http.fixture();
    const { page, context, errors } = await openPage(browser, fixture);
    await page.selectOption('#gp-theme', 'dark');
    await page.selectOption('#gp-width', 'fixed');
    fixture.config.assets = assets('fixture-v2');
    fixture.render.assets_id = 'fixture-v2';
    await Promise.all([page.waitForEvent('domcontentloaded'), Promise.resolve().then(() => fixture.send('render', fixture.render))]);
    await page.waitForFunction(() => document.documentElement.dataset.style === 'official');
    assert.equal(await page.locator('#gp-theme').inputValue(), 'dark');
    assert.equal(await page.locator('#gp-width').inputValue(), 'fixed');
    const count = fixture.requests.filter((path) => path === '').length;
    fixture.send('render', fixture.render);
    await page.waitForTimeout(100);
    assert.equal(fixture.requests.filter((path) => path === '').length, count);
    await Promise.all([page.waitForEvent('domcontentloaded'), Promise.resolve().then(() => fixture.send('reload', {}))]);
    await page.waitForFunction(() => document.documentElement.dataset.style === 'official');
    assert.equal(await page.locator('#gp-theme').inputValue(), 'dark');
    assert.equal(fixture.requests.filter((path) => path === '').length, count + 1);
    assert.deepEqual(errors, []);
    await context.close();
  });

  await t.test('幅・フォント・ヘッダーの高さが変わってもカーソル行に合わせ直す', async () => {
    const html = Array.from({ length: 120 }, (_, i) => `<p id="line-${i + 1}" data-sourcepos="${i + 1}:1-${i + 1}:1">${'日本語の長い文章で折り返し位置を確かめる。'.repeat(12)}</p>`).join('');
    const fixture = http.fixture({ render: payload(html) });
    const { page, context, errors } = await openPage(browser, fixture);
    await page.waitForFunction(() => document.documentElement.dataset.style === 'official');
    const aligned = () => page.waitForFunction(() => {
      const header = document.querySelector('#gp-header').offsetHeight;
      const banner = document.querySelector('#gp-banner');
      const top = header + (banner.hidden ? 0 : banner.offsetHeight);
      return Math.abs(document.querySelector('#line-70').getBoundingClientRect().top - (top + (innerHeight - top) * 0.5)) < 2;
    });
    fixture.send('scroll', { line: 70, ratio: 0.5, lines: 120 });
    await aligned();
    await page.selectOption('#gp-width', 'fixed');
    await aligned();
    await page.evaluate(() => {
      document.querySelector('#gp-content').style.fontSize = '24px';
      document.fonts.dispatchEvent(new Event('loadingdone'));
    });
    await aligned();
    await page.setViewportSize({ width: 500, height: 700 });
    await aligned();
    assert.equal(await page.evaluate(() => parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--gp-header-height')) === document.querySelector('#gp-header').offsetHeight), true);
    assert.deepEqual(errors, []);
    await context.close();
  });
});
