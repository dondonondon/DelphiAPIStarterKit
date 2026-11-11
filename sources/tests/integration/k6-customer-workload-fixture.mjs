import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { gzipSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const scratch = await mkdtemp(join(tmpdir(), 'customer-workload-fixture-'));
const config = join(scratch, 'config.json');
await writeFile(config, '{}');
let state;
const original = { customer_id: '11111111-1111-4111-8111-111111111111', customer_name: 'Existing customer', city: 'Original', notes: 'Not a test fixture' };
const server = createServer(async (req, res) => {
  const match = /^\/api\/v1\/Customer(?:\/([^/]+))?$/.exec(req.url);
  if (!match) { res.writeHead(404).end(); return; }
  assert.equal(req.headers['x-api-token'], 'fixture-token');
  const id = match[1] ? decodeURIComponent(match[1]) : '';
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const input = chunks.length ? JSON.parse(Buffer.concat(chunks)) : null;
  state.calls.push({ method: req.method, id });
  let status = 200;
  let data = [];
  if (req.method === 'GET') {
    data = id ? (state.rows.has(id) ? [state.rows.get(id)] : []) : [...state.rows.values()];
    if (!data.length) { status = 404; data = [{}]; }
  } else if (req.method === 'POST') {
    assert.match(input.customer_name, /^k6-/);
    const record = { ...input, customer_id: randomUUID() };
    state.rows.set(record.customer_id, record);
    status = 201;
    data = [state.wrongCreateId ? { ...record, customer_id: original.customer_id } : record];
  } else if (req.method === 'PUT') {
    assert.notEqual(id, original.customer_id, 'Never update original records');
    assert.ok(state.rows.has(id));
    if (!state.dropUpdates) state.rows.set(id, { ...state.rows.get(id), ...input });
    // Broken fixture can lie in PUT response while leaving the stored value unchanged.
    data = [{ ...state.rows.get(id), ...input }];
  } else if (req.method === 'DELETE') {
    assert.notEqual(id, original.customer_id, 'Never delete original records');
    if (state.failCleanup) { status = 500; data = [{}]; }
    else { assert.ok(state.rows.delete(id)); }
  } else { status = 405; }
  const body = Buffer.from(JSON.stringify({ status, messages: 'Fixture', servertime: '1792962000', data }));
  const gzip = req.headers['accept-encoding'] === 'gzip';
  res.writeHead(status, { 'Content-Type': 'application/json', ...(gzip ? { 'Content-Encoding': 'gzip' } : {}) });
  res.end(gzip ? gzipSync(body) : body);
});
await new Promise((done) => server.listen(0, '127.0.0.1', done));
const base = `http://127.0.0.1:${server.address().port}`;
const env = Object.fromEntries(Object.entries(process.env).filter(([key]) =>
  !/^(K6_|API_TOKEN$|BASE_URL$|FIXED_VUS$|TEST_DURATION$|SMOKE$|ITERATIONS_PER_VU$|PAUSE_SECONDS$|ALLOW_WRITE$|CLEANUP$|RUN_ID$|RESPONSE_ENCODING$|READ_PERCENT$|WRITE_PERCENT$|UPDATE_PERCENT$)/i.test(key)));
env.NO_PROXY = '127.0.0.1';
async function run(mode, settings = {}, expected = 0, fixture = {}) {
  state = { rows: new Map([[original.customer_id, { ...original }]]), calls: [], ...fixture };
  const args = ['run', '--config', config, '--quiet', '--no-usage-report'];
  for (const [key, value] of Object.entries({ BASE_URL: base, API_TOKEN: 'fixture-token', FIXED_VUS: '2',
    SMOKE: '1', PAUSE_SECONDS: '0', ALLOW_WRITE: '1', RUN_ID: 'fixture-run', ...settings })) args.push('-e', `${key}=${value}`);
  args.push(join(root, `docs/k6/customer-${mode}-test.js`));
  const result = await new Promise((done, reject) => {
    const child = spawn('k6', args, { env, windowsHide: true });
    let output = '';
    const timer = setTimeout(() => child.kill(), 30000);
    child.stdout.on('data', (b) => { output += b; });
    child.stderr.on('data', (b) => { output += b; });
    child.once('error', (error) => { clearTimeout(timer); reject(error); });
    child.once('close', (code) => { clearTimeout(timer); done({ code, output }); });
  });
  assert.equal(result.code === 0, expected === 0, `${mode} unexpected exit ${result.code}\n${result.output}`);
  assert.deepEqual(state.rows.get(original.customer_id), original);
  if (expected === 0 && settings.CLEANUP !== '0') assert.equal(state.rows.size, 1, 'Owned records cleaned');
  console.log(`PASS ${mode} ${JSON.stringify(settings)} expected=${expected === 0 ? 'pass' : 'fail'}`);
  return state.calls;
}
try {
  const readCalls = await run('read');
  assert.ok(readCalls.every((c) => c.method === 'GET'));
  for (const mode of ['write', 'update', 'full-flow']) await run(mode, { ITERATIONS_PER_VU: '2' });
  const mixed = await run('mixed', { ITERATIONS_PER_VU: '100' });
  for (const method of ['GET', 'POST', 'PUT', 'DELETE']) assert.ok(mixed.some((c) => c.method === method));
  assert.equal(mixed.filter((c) => c.method === 'GET' && !c.id).length, 140, '70% of 200 operations read lists');
  assert.equal(mixed.filter((c) => c.method === 'POST').length, 42, '20% inserts plus two setup seeds');
  assert.equal(mixed.filter((c) => c.method === 'PUT').length, 20, '10% updates');
  await run('write', { ALLOW_WRITE: '0' }, 1);
  assert.equal(state.calls.length, 0);
  await run('update', { FIXED_VUS: '0' }, 1);
  assert.equal(state.calls.length, 0);
  await run('mixed', { READ_PERCENT: '60' }, 1);
  assert.equal(state.calls.length, 0);
  await run('write', { RUN_ID: 'invalid space' }, 1);
  assert.equal(state.calls.length, 0);
  await run('update', {}, 1, { dropUpdates: true });
  await run('write', {}, 1, { failCleanup: true });
  await run('write', {}, 1, { wrongCreateId: true });
  assert.ok(state.calls.every((c) => c.method !== 'DELETE'));
  await run('write', { CLEANUP: '0' });
  assert.ok(state.rows.size > 1);
  assert.ok(state.calls.every((c) => c.method !== 'DELETE'));
  console.log('PASS all Customer workload integration cases (mock HTTP only).');
} finally {
  await new Promise((done) => server.close(done));
  await rm(scratch, { recursive: true, force: true });
}
