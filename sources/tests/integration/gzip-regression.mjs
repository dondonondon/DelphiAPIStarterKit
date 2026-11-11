import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { request } from 'node:http';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { gunzipSync } from 'node:zlib';

const executable = resolve(process.argv[2]);
const scratch = await mkdtemp(join(tmpdir(), 'delphi-gzip-http-'));
let checks = 0;
const check = (condition, message) => { assert.ok(condition, message); checks++; };

async function start(config, reject = false) {
  const file = join(scratch, `case-${checks}-${Math.random().toString(16).slice(2)}.ini`);
  await writeFile(file, config);
  const child = spawn(executable, ['--isolated-fixture'], {
    cwd: scratch, windowsHide: true,
    env: { ...process.env, DELPHI_API_CONFIG: file },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let output = '', errors = '';
  const exited = new Promise((res) => child.once('close', res));
  child.stderr.on('data', (chunk) => { errors += chunk; });
  const ready = await new Promise((res, rej) => {
    const timer = setTimeout(() => { child.kill(); rej(new Error('Fixture startup timed out')); }, 10000);
    child.on('error', (error) => { clearTimeout(timer); rej(error); });
    child.stdout.on('data', (chunk) => {
      output += chunk;
      const match = /READY (\d+)/.exec(output);
      if (match) { clearTimeout(timer); res(Number(match[1])); }
    });
    child.once('close', (code) => {
      clearTimeout(timer);
      if (reject) res({ code, output });
      else rej(new Error(`Fixture exited ${code}: ${output} ${errors}`));
    });
  });
  if (reject) {
    if (typeof ready === 'number') {
      child.stdin.end('stop\n');
      await exited;
      throw new Error('Invalid HTTP configuration unexpectedly started a listener');
    }
    check(ready.code === 1 && ready.output.includes('ERROR [HTTP]'), 'Invalid HTTP configuration fails startup');
    return;
  }
  return {
    file, port: ready,
    async stop() {
      child.stdin.end('stop\n');
      const timer = setTimeout(() => child.kill(), 10000);
      try { check(await exited === 0, 'Fixture stops cleanly'); }
      finally { clearTimeout(timer); }
    },
  };
}

async function get(server, path = '/large', headers = {}, method = 'GET') {
  return new Promise((res, rej) => {
    const req = request({ hostname: '127.0.0.1', port: server.port, path, method, headers, agent: false }, (response) => {
      const chunks = [];
      response.on('data', (chunk) => chunks.push(chunk));
      response.on('end', () => res({ code: response.statusCode, headers: response.headers, body: Buffer.concat(chunks) }));
      response.on('error', rej);
    });
    req.on('error', rej);
    req.setTimeout(10000, () => req.destroy(new Error('HTTP fixture timeout')));
    req.end();
  });
}

const server = await start(''); // Missing [HTTP] uses True / 1024 / 1.
try {
  const plain = await get(server);
  check(!plain.headers['content-encoding'], 'Absent Accept-Encoding keeps identity');
  check(plain.headers['content-type'] === 'application/json; charset=utf-8', 'UTF-8 is the charset');
  check(JSON.parse(plain.body).data[0].notes.includes('café 日本語 —'), 'Unicode characters reach the client intact');
  const compressed = await get(server, '/large', { 'Accept-Encoding': 'gzip' });
  check(compressed.headers['content-encoding'] === 'gzip', 'Gzip selected');
  check(compressed.body[0] === 0x1f && compressed.body[1] === 0x8b, 'Actual gzip header');
  check(Number(compressed.headers['content-length']) === compressed.body.length, 'Compressed Content-Length matches wire bytes');
  check(gunzipSync(compressed.body).equals(plain.body), 'Decompressed UTF-8 bytes exactly match identity');
  check(JSON.parse(gunzipSync(compressed.body)).data.length === 2305, 'All Unicode JSON records survive compression');
  check(compressed.body.length < plain.body.length, 'Compression reduces this fixture');
  console.log(`Fixture bytes: identity=${plain.body.length}, gzip-level1=${compressed.body.length}`);

  for (const [header, expected] of [
    ['GZip', true], ['br, gzip;q=0.5', true], ['gzip;q=0', false],
    ['*;q=0.5', true], ['*;q=1, gzip;q=0', false], ['*;q=0, gzip;q=1', true],
    ['deflate', false], ['gzip;q=bogus', false], ['gzip;q=1.001', false],
    ['gzip;q=0.000', false], ['gzip;q=1.000', true], ['gzip;q=0.0001', false],
    ['gzip;q=0, gzip;q=1', false], ['x-gzip', true], ['gzip;q=0.001', true],
    [',gzip,', true], ['gzip;q=1;q=0', false], ['gzip;unknown=1', false],
  ]) {
    const response = await get(server, '/large', { 'Accept-Encoding': header });
    check((response.headers['content-encoding'] === 'gzip') === expected, `Negotiation ${header}`);
    check(response.headers.vary.toLowerCase().includes('accept-encoding'), 'Vary covers compressed and identity negotiation');
  }
  for (const [path, encoding] of [
    ['/small', undefined], ['/below', undefined], ['/exact', 'gzip'], ['/unicode-threshold', 'gzip'], ['/empty', undefined],
    ['/image', undefined], ['/stream', undefined], ['/already', 'br'], ['/no-transform', undefined],
    ['/partial', undefined], ['/no-content', undefined], ['/etag', undefined], ['/sent', undefined],
    ['/error', 'gzip'],
  ]) {
    const response = await get(server, path, { 'Accept-Encoding': 'gzip' });
    check(response.headers['content-encoding'] === encoding, `Response policy ${path}`);
    if (encoding === 'gzip') check(gunzipSync(response.body).length > 0, `Valid gzip ${path}`);
  }
  check(!(await get(server, '/large', { 'Accept-Encoding': 'gzip', Range: 'bytes=0-99' })).headers['content-encoding'], 'Range request skipped');
  const head = await get(server, '/large', { 'Accept-Encoding': 'gzip' }, 'HEAD');
  check(!head.headers['content-encoding'] && head.body.length === 0, 'HEAD has no compressed body');
  for (const value of ['Origin', 'Origin, accept-encoding', '*']) {
    const response = await get(server, '/vary', { 'Accept-Encoding': 'gzip', 'X-Fixture-Vary': value });
    check(response.headers.vary === (value === 'Origin' ? 'Origin, Accept-Encoding' : value), 'Existing Vary merged without duplicates');
  }
  const concurrent = await Promise.all(Array.from({ length: 32 }, () => get(server, '/large', { 'Accept-Encoding': 'gzip' })));
  for (const response of concurrent) check(gunzipSync(response.body).equals(plain.body), 'Concurrent gzip uses independent streams');
  await writeFile(server.file, '[HTTP]\nGzipEnabled=False\n');
  check((await get(server, '/large', { 'Accept-Encoding': 'gzip' })).headers['content-encoding'] === 'gzip', 'HTTP configuration remains cached until restart');
} finally { await server.stop(); }

for (let level = 1; level <= 9; level++) {
  const instance = await start(`[HTTP]\nGzipEnabled=True\nGzipMinimumBytes=0\nGzipLevel=${level}\n`);
  try {
    const plain = await get(instance);
    const response = await get(instance, '/large', { 'Accept-Encoding': 'gzip' });
    check(response.headers['content-encoding'] === 'gzip' && gunzipSync(response.body).equals(plain.body), `Numeric gzip level ${level} round-trip`);
    const tiny = await get(instance, '/small', { 'Accept-Encoding': 'gzip' });
    check(!tiny.headers['content-encoding'], 'Larger gzip output falls back to identity');
  } finally { await instance.stop(); }
}
for (const config of ['GzipEnabled=False', 'GzipMinimumBytes=1000000']) {
  const instance = await start(`[HTTP]\n${config}\n`);
  try { check(!(await get(instance, '/large', { 'Accept-Encoding': 'gzip' })).headers['content-encoding'], 'Disabled/threshold configuration honored'); }
  finally { await instance.stop(); }
}
for (const config of ['GzipEnabled=invalid', 'GzipMinimumBytes=-1', 'GzipMinimumBytes=x', 'GzipLevel=0', 'GzipLevel=10', 'GzipLevel=x']) {
  await start(`[HTTP]\n${config}\n`, true);
}
console.log(`PASS gzip HTTP regression: ${checks} checks; real Indy/WebBroker loopback, Node gzip decoder.`);
