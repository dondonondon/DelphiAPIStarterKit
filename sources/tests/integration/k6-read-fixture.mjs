// Run with: node sources/tests/integration/k6-read-fixture.mjs
// Uses only a temporary loopback HTTP fixture and a dummy token; no database/API access.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtemp, rmdir, unlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const script = join(projectRoot, 'docs/k6/api-read-test-all.js');
const scratch = await mkdtemp(join(tmpdir(), 'delphi-api-k6-fixture-'));
const config = join(scratch, 'config.json');
await writeFile(config, '{}');

const resources = new Map([
  ['User', 'user_id'], ['Product', 'product_id'],
  ['Category', 'category_id'], ['Customer', 'customer_id'],
]);
let fixture;
const server = createServer((request, response) => {
  const match = /^\/api\/v1\/(User|Product|Category|Customer)(?:\/([^/]+))?$/.exec(request.url);
  if (request.method !== 'GET' || !match) {
    response.writeHead(404).end();
    return;
  }
  assert.equal(request.headers['x-api-token'], 'local-fixture-token');
  const [, resource, id] = match;
  const key = `${resource}_${id ? 'detail' : 'list'}`;
  fixture.calls[key] = (fixture.calls[key] || 0) + 1;
  fixture.encodings.add(request.headers['accept-encoding']);
  let count = resource === 'Customer' ? 2300 : 2;
  if (fixture.truncateLoad && key === 'Customer_list' && fixture.calls[key] > 1) count--;
  const idField = resources.get(resource);
  const data = id
    ? [{ [idField]: decodeURIComponent(id) }]
    : Array.from({ length: count }, (_, index) => ({ [idField]: `fixture-${resource}-${index + 1}` }));
  const body = JSON.stringify({ status: 200, messages: 'OK', servertime: '1792962000', data });
  const compressed = request.headers['accept-encoding'] === 'gzip';
  response.writeHead(200, { 'Content-Type': 'application/json', ...(compressed ? { 'Content-Encoding': 'gzip' } : {}) });
  response.end(compressed ? gzipSync(body) : body);
});
await new Promise((resolveListen, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolveListen);
});
const baseURL = `http://127.0.0.1:${server.address().port}`;
const childEnv = Object.fromEntries(Object.entries(process.env).filter(([name]) =>
  !/^(K6_|EXPECTED_|RESPONSE_ENCODING$|API_TOKEN$|BASE_URL$|RESOURCE$|ENDPOINT$|FIXED_VUS$|TEST_DURATION$|SMOKE$|IMAGE_FILENAME$|USER_ID$|PRODUCT_ID$|CATEGORY_ID$|CUSTOMER_ID$)/i.test(name)));
childEnv.NO_PROXY = '127.0.0.1';

async function runCase(name, settings, verify, truncateLoad = false) {
  fixture = { calls: {}, truncateLoad, encodings: new Set() };
  const args = ['run', '--config', config, '--quiet', '--no-usage-report', '--log-format=raw'];
  for (const [key, value] of Object.entries({
    BASE_URL: baseURL, API_TOKEN: 'local-fixture-token', SMOKE: '1', ...settings,
  })) args.push('-e', `${key}=${value}`);
  args.push(script);
  const result = await new Promise((resolveRun, reject) => {
    const child = spawn('k6', args, { cwd: projectRoot, env: childEnv, windowsHide: true });
    let output = '';
    const timeout = setTimeout(() => child.kill(), 30000);
    child.stdout.on('data', (chunk) => { output += chunk; });
    child.stderr.on('data', (chunk) => { output += chunk; });
    child.on('error', (error) => { clearTimeout(timeout); reject(error); });
    child.on('close', (code) => { clearTimeout(timeout); resolveRun({ code, output }); });
  });
  try {
    verify(result, fixture.calls);
  } catch (error) {
    console.error(`Fixture case: ${name}\n${result.output}`);
    error.message += `\nFixture case: ${name}\n${result.output}`;
    throw error;
  }
  console.log(`PASS ${name}`);
}

try {
  for (const encoding of ['gzip', 'identity']) {
    await runCase(`explicit ${encoding} response encoding`, { RESPONSE_ENCODING: encoding }, ({ code }) => {
      assert.equal(code, 0);
      assert.deepEqual([...fixture.encodings], [encoding]);
    });
  }
  await runCase('invalid response encoding rejected', { RESPONSE_ENCODING: 'unknown' }, ({ code, output }, calls) => {
    assert.notEqual(code, 0);
    assert.match(output, /RESPONSE_ENCODING must be auto, gzip, or identity/);
    assert.deepEqual(calls, {});
  });
  await runCase('default eight GET endpoints', {
    EXPECTED_USER_ROWS: '2', EXPECTED_PRODUCT_ROWS: '2',
    EXPECTED_CATEGORY_ROWS: '2', EXPECTED_CUSTOMER_ROWS: '2300',
  }, ({ code, output }, calls) => {
    assert.equal(code, 0);
    assert.match(output, /Preflight passed: 8 GET endpoints/);
    assert.equal(Object.keys(calls).length, 8);
    for (const count of Object.values(calls)) assert.equal(count, 2);
  });
  await runCase('list-only complete 2300 rows', {
    RESOURCE: 'Customer', ENDPOINT: 'list', EXPECTED_CUSTOMER_ROWS: '2300',
  }, ({ code }, calls) => {
    assert.equal(code, 0);
    assert.deepEqual(calls, { Customer_list: 2 });
  });
  await runCase('detail-only retains list ID discovery', {
    RESOURCE: 'Customer', ENDPOINT: 'detail', EXPECTED_CUSTOMER_ROWS: '2300',
  }, ({ code }, calls) => {
    assert.equal(code, 0);
    assert.deepEqual(calls, { Customer_list: 1, Customer_detail: 2 });
  });
  await runCase('wrong expected count rejects preflight', {
    RESOURCE: 'Customer', ENDPOINT: 'list', EXPECTED_CUSTOMER_ROWS: '2301',
  }, ({ code, output }, calls) => {
    assert.notEqual(code, 0);
    assert.match(output, /preflight failed/);
    assert.doesNotMatch(output, /Preflight passed/);
    assert.deepEqual(calls, { Customer_list: 1 });
  });
  await runCase('truncated list fails checks during load', {
    RESOURCE: 'Customer', ENDPOINT: 'list', EXPECTED_CUSTOMER_ROWS: '2300',
  }, ({ code, output }, calls) => {
    assert.notEqual(code, 0);
    assert.match(output, /Preflight passed: 1 GET endpoints/);
    assert.match(output, /row count matches expected fixture/);
    assert.deepEqual(calls, { Customer_list: 2 });
  }, true);
  for (const expectedCount of ['0', '-1', '1.5', 'invalid', '', '9007199254740992']) {
    await runCase(`invalid expected row count ${JSON.stringify(expectedCount)}`, {
      RESOURCE: 'Customer', EXPECTED_CUSTOMER_ROWS: expectedCount,
    }, ({ code, output }, calls) => {
      assert.notEqual(code, 0);
      assert.match(output, /EXPECTED_CUSTOMER_ROWS must be a positive safe integer/);
      assert.deepEqual(calls, {});
    });
  }
  await runCase('invalid endpoint rejects configuration', { ENDPOINT: 'unknown' }, ({ code, output }, calls) => {
    assert.notEqual(code, 0);
    assert.match(output, /ENDPOINT must be all, list, or detail/);
    assert.deepEqual(calls, {});
  });
} finally {
  server.closeAllConnections();
  await new Promise((resolveClose) => server.close(resolveClose));
  await unlink(config);
  await rmdir(scratch);
}
