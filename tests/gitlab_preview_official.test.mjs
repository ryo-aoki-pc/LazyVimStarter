// 実際に取得した固定版の資産を、Lua の HTTP サーバーと Edge / Chromium で確かめる。
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync } from 'node:fs';
import { mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')); } catch {}
const browserPath = [
  process.env.EDGE_BIN, process.env.CHROME_BIN,
  process.platform === 'win32' && join(process.env['ProgramFiles(x86)'] || '', 'Microsoft/Edge/Application/msedge.exe'),
  process.platform === 'win32' && join(process.env.ProgramFiles || '', 'Google/Chrome/Application/chrome.exe'),
  chromium && chromium.executablePath(),
].find((path) => path && existsSync(path));
const root = fileURLToPath(new URL('../', import.meta.url));
const outputDir = join(root, '.tests');
const dataDir = process.env.GITLAB_PREVIEW_TEST_DATA || join(outputDir, 'gitlab-preview-data');
const lockText = await readFile(join(root, 'lua/config/gitlab_preview/assets.lock.json'), 'utf8');
const lock = JSON.parse(lockText);
const id = lock.version + '-' + createHash('sha256').update(lockText).digest('hex').slice(0, 12);
const assetDir = join(dataDir, 'gitlab-preview/assets', id);
const manifestPath = join(assetDir, 'install.json');
const stickyPath = process.env.MD_TABLE_STICKY_SOURCE || join(outputDir, 'md-table-sticky.js');
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

test('取得済みの公式スタイルと Lua サーバー', {
  skip: !chromium || !browserPath || !existsSync(manifestPath) ? 'Playwright、ブラウザ、固定版の導入済み資産が必要' : false,
}, async (t) => {
  await mkdir(outputDir, { recursive: true });
  const temp = await mkdtemp(join(outputDir, 'official-browser-'));
  const urlFile = join(temp, 'url.txt');
  const stopFile = join(temp, 'stop.txt');
  const nvim = spawn(process.env.NVIM_BIN || 'nvim', [
    '--headless', '-u', 'NONE', '-i', 'NONE', '-l', join(root, 'tests/gitlab_preview_browser_fixture.lua'), dataDir, urlFile, stopFile,
  ], { cwd: root, windowsHide: true });
  let log = '';
  let exited = false;
  nvim.stdout.on('data', (chunk) => { log += chunk; });
  nvim.stderr.on('data', (chunk) => { log += chunk; });
  nvim.once('close', () => { exited = true; });
  t.after(async () => {
    await writeFile(stopFile, 'stop');
    for (let i = 0; i < 100 && !exited; i++) await pause(20);
    if (!exited) nvim.kill();
    assert.ok(temp.startsWith(join(root, '.tests') + '\\') || temp.startsWith(join(root, '.tests') + '/'));
    await rm(temp, { recursive: true, force: true });
  });
  for (let i = 0; i < 750 && !existsSync(urlFile) && !exited; i++) await pause(20);
  assert.ok(existsSync(urlFile), 'Lua の HTTP 起動に失敗: ' + log);
  const base = (await readFile(urlFile, 'utf8')).trim();
  const browser = await chromium.launch({ executablePath: browserPath, headless: true });
  t.after(() => browser.close());
  const context = await browser.newContext({ viewport: { width: 2000, height: 1000 }, colorScheme: 'light' });
  await context.route('**/*', (route) => route.request().url().startsWith(base) ? route.continue() : route.abort());
  const page = await context.newPage();
  page.setDefaultTimeout(10000);
  const errors = [];
  const failed = [];
  const responses = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('requestfailed', (req) => failed.push(req.url()));
  page.on('response', (res) => { if (res.url().includes('/_/assets/')) responses.push({ url: res.url(), status: res.status() }); });
  await page.goto(base);
  await page.waitForFunction(() => document.documentElement.dataset.style === 'official');
  await page.evaluate(async () => { await document.fonts.ready; });
  assert.deepEqual(errors, []);
  assert.equal(await page.locator('#gp-content h1').textContent(), 'GitLab プレビューの表示確認');
  assert.equal(await page.locator('#gp-fallback-style').count(), 0);
  assert.ok(await page.locator('#gp-page').evaluate((el) => el.getBoundingClientRect().width) > 1600);
  await page.selectOption('#gp-width', 'fixed');
  assert.equal(await page.locator('#gp-page').evaluate((el) => el.getBoundingClientRect().width), 1600);
  await page.selectOption('#gp-width', 'fluid');

  // フォント名の指定だけでなく、実際の WOFF2 が読まれていることを確かめる。
  const fonts = await page.evaluate(() => [...document.fonts].filter((face) => face.status === 'loaded').map((face) => face.family));
  assert.ok(fonts.some((name) => name.includes('GitLab Sans')), JSON.stringify(fonts));
  assert.ok(fonts.some((name) => name.includes('GitLab Mono')), JSON.stringify(fonts));
  assert.ok(responses.filter((res) => res.url.endsWith('.woff2') && res.status === 200).length >= 2);
  await page.waitForFunction(() => document.querySelector('#official-sprite use').getBBox().width > 0);

  // 同じ本体 CSS を使う参照 DOM と、本文の書体・寸法・色が一致することを確かめる。
  const compareReference = () => page.evaluate(() => {
    const content = document.querySelector('#gp-content');
    const holder = document.createElement('div');
    holder.className = 'file-holder';
    holder.style.cssText = 'position:absolute;left:-20000px;top:0;visibility:hidden;width:' + content.getBoundingClientRect().width + 'px';
    const reference = content.cloneNode(true);
    reference.removeAttribute('id');
    reference.style.cssText = 'box-sizing:border-box;width:100%;max-width:none;margin:0;padding:16px 24px 50vh';
    holder.append(reference);
    document.body.append(holder);
    const properties = ['fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'lineHeight', 'color', 'backgroundColor', 'marginTop', 'marginBottom', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'borderTopWidth', 'borderTopColor'];
    const selectors = ['h1', 'h2', 'p', 'table', 'th', 'td', 'pre', 'pre code', '.s', '.c1', 'blockquote', 'summary'];
    const result = selectors.map((selector) => {
      const actual = getComputedStyle(content.querySelector(selector));
      const expected = getComputedStyle(reference.querySelector(selector));
      return { selector, actual: Object.fromEntries(properties.map((key) => [key, actual[key]])), expected: Object.fromEntries(properties.map((key) => [key, expected[key]])) };
    });
    holder.remove();
    return result;
  });
  for (const result of await compareReference()) assert.deepEqual(result.actual, result.expected, result.selector);
  const stringColor = await page.locator('.highlight .s').evaluate((el) => getComputedStyle(el).color);
  const codeColor = await page.locator('.highlight code').evaluate((el) => getComputedStyle(el).color);
  assert.notEqual(stringColor, codeColor, 'Dracula の構文色を適用する');
  const metrics = { id, fonts, light: await compareReference(), stringColor, codeColor };
  await page.screenshot({ path: join(outputDir, 'official-preview-light.png') });

  await page.selectOption('#gp-theme', 'dark');
  await page.waitForFunction(() => document.documentElement.classList.contains('gl-dark') && getComputedStyle(document.body).backgroundColor !== 'rgb(255, 255, 255)');
  // テーマ資産の読込完了は active な stylesheet の media で判定する。
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  await page.waitForFunction((lastStyle) => [...document.querySelectorAll('link')].some((link) => link.href.endsWith(lastStyle) && link.media === 'all'), manifest.styles.dark.at(-1));
  for (const result of await compareReference()) assert.deepEqual(result.actual, result.expected, 'dark: ' + result.selector);
  metrics.dark = await compareReference();
  await page.screenshot({ path: join(outputDir, 'official-preview-dark.png') });

  await t.test('実 md-table-sticky の全幅パネルでも公式の表と配色を保つ', { skip: !existsSync(stickyPath) ? 'MD_TABLE_STICKY_SOURCE に本体のソースを指定する' : false }, async () => {
    await page.evaluate(await readFile(stickyPath, 'utf8'));
    await page.waitForSelector('[data-md-table-sticky-action="float"]');
    await page.evaluate(() => { window.originalTable = document.querySelector('#gp-content table'); });
    const padding = await page.locator('#gp-content td').first().evaluate((el) => getComputedStyle(el).paddingLeft);
    await page.locator('[data-md-table-sticky-action="float"]').first().click();
    await page.waitForSelector('[data-md-table-sticky-float-panel]');
    assert.equal(await page.evaluate(() => document.querySelector('[data-md-table-sticky-float-panel] table') === window.originalTable), true);
    assert.equal(await page.locator('[data-md-table-sticky-float-panel] td').first().evaluate((el) => getComputedStyle(el).paddingLeft), padding);
    await page.evaluate(() => { const select = document.querySelector('#gp-theme'); select.value = 'light'; select.dispatchEvent(new Event('change')); });
    await page.waitForFunction(() => getComputedStyle(document.querySelector('[data-md-table-sticky-float-panel]')).backgroundColor === getComputedStyle(document.body).backgroundColor && !document.documentElement.classList.contains('gl-dark'));
    assert.equal(await page.evaluate(() => document.querySelector('[data-md-table-sticky-float-panel] table') === window.originalTable), true);
    await page.screenshot({ path: join(outputDir, 'official-preview-table.png') });
    await page.keyboard.press('Escape');
    await page.waitForSelector('[data-md-table-sticky-float-panel]', { state: 'detached' });
    assert.equal(await page.evaluate(() => document.querySelector('#gp-content table') === window.originalTable), true);
  });

  await page.selectOption('#gp-width', 'fixed');
  await page.setViewportSize({ width: 700, height: 800 });
  await page.evaluate(() => document.querySelector('#line-60').scrollIntoView());
  assert.ok(await page.locator('#gp-content').evaluate((el) => el.getBoundingClientRect().width) <= 700);
  assert.deepEqual(errors, []);
  assert.deepEqual(failed, []);
  assert.ok(responses.every((res) => res.status === 200 || res.status === 304), JSON.stringify(responses));
  await writeFile(join(outputDir, 'official-preview-metrics.json'), JSON.stringify(metrics, null, 2));

  // 公開 GitLab.com との比較は明示した実行だけで試みる。到達できなければ未実施として記録する。
  if (process.env.GITLAB_PREVIEW_COMPARE_GITLABCOM === '1') {
    const publicContext = await browser.newContext({ viewport: { width: 2000, height: 1000 }, colorScheme: 'light' });
    const publicPage = await publicContext.newPage();
    let result;
    try {
      const response = await publicPage.goto('https://gitlab.com/gitlab-org/gitlab-foss/-/blob/v19.5.1/README.md', { waitUntil: 'domcontentloaded', timeout: 20000 });
      await publicPage.waitForSelector('.file-content.md', { timeout: 10000 });
      result = { status: 'reachable', httpStatus: response.status(), url: publicPage.url(), font: await publicPage.locator('.file-content.md').first().evaluate((el) => ({ family: getComputedStyle(el).fontFamily, size: getComputedStyle(el).fontSize, lineHeight: getComputedStyle(el).lineHeight })) };
      await publicPage.screenshot({ path: join(outputDir, 'gitlabcom-public-reference.png') });
      t.diagnostic('GitLab.com の公開ファイルへ到達。記録した本文 metrics を確認する。');
    } catch (error) {
      result = { status: 'unavailable', reason: error.message.split('\n')[0], title: await publicPage.title().catch(() => ''), url: publicPage.url() };
      t.diagnostic('GitLab.com の画面比較は未実施: ' + result.reason);
    }
    await writeFile(join(outputDir, 'gitlabcom-comparison.json'), JSON.stringify(result, null, 2));
    await publicContext.close();
  }
});
