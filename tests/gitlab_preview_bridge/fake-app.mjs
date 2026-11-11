// 本物のアプリや通信を使わず、取り決めの行を記録し、試験が指定した応答を返す。
import { readFileSync, appendFileSync } from 'node:fs';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
const directory = process.env.MD_PREVIEW_BRIDGE_TEST_DIR;
if (!directory) throw new Error('試験用のフォルダーを指定してください');
const read = (file, fallback) => { try { return JSON.parse(readFileSync(join(directory, file), 'utf8')); } catch { return fallback; } };
const config = read('config.json', {});
const mode = process.argv[2];
const log = value => appendFileSync(join(directory, 'events.jsonl'), JSON.stringify({ pid: process.pid, mode, ...value }) + '\n');
let stdinClosed = false;
log({ kind: 'start', argv: process.argv.slice(2) });
process.on('exit', code => log({ kind: 'exit', code, stdinClosed }));
process.stdout.on('error', () => {});
if (mode === 'install-style') {
  await new Promise(resolve => setTimeout(resolve, config.installDelay ?? 100));
  process.stdout.write('導入の途中\n' + (config.installOutput || '公式スタイルの導入が完了しました') + '\n');
  if (config.installExit) process.stderr.write('前の誤り\n' + (config.installError || '公式スタイルを導入できませんでした') + '\n');
  process.exitCode = config.installExit || 0;
} else if (mode === '--stdio') {
  let queue = Promise.resolve(), readyTimer, processed = 0, polling = false;
  function emit(value, raw = false) {
    queue = queue.then(async () => {
      const line = raw ? value : JSON.stringify(value) + '\n';
      if (config.split !== false) {
        const buffer = Buffer.from(line);
        const japanese = buffer.indexOf(Buffer.from('日'));
        const at = japanese >= 0 ? japanese + 1 : Math.max(1, Math.floor(buffer.length / 2));
        process.stdout.write(buffer.subarray(0, at));
        await new Promise(resolve => setTimeout(resolve, 3));
        process.stdout.write(buffer.subarray(at));
      } else process.stdout.write(line);
      log({ kind: 'emitted', value });
    });
    return queue;
  }
  if (config.stderr) process.stderr.write(config.stderr);
  const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
  input.on('line', line => {
    let message;
    try { message = JSON.parse(line); } catch { message = null; }
    log({ kind: 'input', line, message });
    if (message?.type === 'hello' && config.ready !== false) {
      readyTimer = setTimeout(() => {
        emit({ type: 'ready', protocol: config.protocol ?? 1, version: '試験用', url: 'http://127.0.0.1:12345/fixture-' + process.pid + '/', ...config.readyFields });
        emit({ type: 'clients', count: config.clients ?? 0 });
      }, config.readyDelay || 0);
    }
  });
  const poll = setInterval(async () => {
    if (polling) return;
    polling = true;
    try {
      const commands = read('commands.json', []);
      while (processed < commands.length) {
        const command = commands[processed++];
        if (command.pid !== process.pid) continue;
        if (command.kind === 'exit') process.exit(command.code || 0);
        if (command.kind === 'stderr') process.stderr.write(command.text);
        else if (command.kind === 'raw') await emit(command.text, true);
        else await emit(command.value);
        log({ kind: 'command', index: processed });
      }
    } finally { polling = false; }
  }, 10);
  input.on('close', () => {
    stdinClosed = true;
    log({ kind: 'stdin-end' });
    if (!config.ignoreEOF) { clearInterval(poll); clearTimeout(readyTimer); }
  });
} else {
  process.stderr.write('試験用の引数が違います\n');
  process.exitCode = 2;
}
