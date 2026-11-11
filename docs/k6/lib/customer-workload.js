import http from 'k6/http';
import exec from 'k6/execution';
import { check, sleep } from 'k6';
import { Counter, Rate } from 'k6/metrics';

const operations = new Counter('workload_operations');
const completed = new Rate('workload_success');

export function workload(mode) {
  const base = (__ENV.BASE_URL || 'http://127.0.0.1:9999').replace(/\/+$/, '');
  const token = (__ENV.API_TOKEN || '').trim();
  const vus = Number(__ENV.FIXED_VUS || '5');
  const iterations = Number(__ENV.ITERATIONS_PER_VU || '1');
  const pause = Number(__ENV.PAUSE_SECONDS === undefined ? '0.2' : __ENV.PAUSE_SECONDS);
  const encoding = __ENV.RESPONSE_ENCODING || 'gzip';
  const cleanup = __ENV.CLEANUP !== '0';
  const writes = mode !== 'read';
  const readWeight = Number(__ENV.READ_PERCENT === undefined ? '70' : __ENV.READ_PERCENT);
  const writeWeight = Number(__ENV.WRITE_PERCENT === undefined ? '20' : __ENV.WRITE_PERCENT);
  const updateWeight = Number(__ENV.UPDATE_PERCENT === undefined ? '10' : __ENV.UPDATE_PERCENT);
  if (!token) throw new Error('API_TOKEN is required (x-api-token).');
  if (writes && __ENV.ALLOW_WRITE !== '1') throw new Error('Set ALLOW_WRITE=1 for a dedicated test database.');
  if (!/^https?:\/\//i.test(base)) throw new Error('BASE_URL must use HTTP or HTTPS.');
  if (!Number.isSafeInteger(vus) || vus < 1) throw new Error('FIXED_VUS must be a positive integer.');
  if (!Number.isSafeInteger(iterations) || iterations < 1) throw new Error('ITERATIONS_PER_VU must be a positive integer.');
  if (!Number.isFinite(pause) || pause < 0) throw new Error('PAUSE_SECONDS must be nonnegative.');
  if (!['auto', 'gzip', 'identity'].includes(encoding)) throw new Error('Invalid RESPONSE_ENCODING.');
  if (__ENV.CLEANUP !== undefined && !['0', '1'].includes(__ENV.CLEANUP)) throw new Error('CLEANUP must be 0 or 1.');
  if ([readWeight, writeWeight, updateWeight].some((n) => !Number.isInteger(n) || n < 0) ||
      readWeight + writeWeight + updateWeight !== 100) throw new Error('Mixed percentages must be nonnegative integers summing to 100.');
  if (__ENV.RUN_ID && !/^[a-zA-Z0-9_-]{1,40}$/.test(__ENV.RUN_ID)) throw new Error('RUN_ID must be 1..40 safe characters.');
  const required = mode === 'read' ? ['read_list', 'read_detail'] : mode === 'write' ? ['create'] :
    mode === 'update' ? ['update'] : mode === 'full-flow' ? ['create', 'update'] :
      [...(readWeight ? ['read_list', 'read_detail'] : []), ...(writeWeight ? ['create'] : []), ...(updateWeight ? ['update'] : [])];
  const thresholds = { checks: ['rate==1'], workload_success: ['rate==1'], http_req_failed: ['rate<0.01'],
    'http_req_duration{phase:load}': ['p(95)<500'] };
  for (const operation of required) {
    thresholds[`http_req_duration{phase:load,operation:${operation}}`] = ['p(95)<500'];
    thresholds[`http_reqs{phase:load,operation:${operation}}`] = ['count>0'];
  }
  const options = {
    scenarios: { workload: __ENV.SMOKE === '1'
      ? { executor: 'per-vu-iterations', vus, iterations, maxDuration: '5m' }
      : { executor: 'constant-vus', vus, duration: __ENV.TEST_DURATION || '60s', gracefulStop: '30s' } },
    thresholds, setupTimeout: '5m', teardownTimeout: '5m',
    summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
  };

  function request(method, id, payload, phase, operation, expected = 200) {
    const route = '/api/v1/Customer';
    const headers = { 'x-api-token': token, Accept: 'application/json', 'Content-Type': 'application/json' };
    if (encoding !== 'auto') headers['Accept-Encoding'] = encoding;
    const res = http.request(method, base + route + (id ? '/' + encodeURIComponent(id) : ''),
      payload === null ? null : JSON.stringify(payload), {
        headers, tags: { name: `${method} ${route}${id ? '/{id}' : ''}`, phase, operation },
        timeout: '30s', redirects: 0, responseCallback: http.expectedStatuses(expected),
      });
    let body;
    try { body = res.json(); } catch (_) { body = null; }
    const valid = check(res, {
      [`${operation}: expected HTTP status`]: (r) => r.status === expected,
      [`${operation}: JSON envelope`]: () => body && body.status === expected &&
        typeof body.messages === 'string' && typeof body.servertime === 'string' && /^\d+$/.test(body.servertime) &&
        Array.isArray(body.data) && /^application\/json\b/i.test(res.headers['Content-Type'] || ''),
    });
    if (!valid) console.warn(`API check failed: operation=${operation} phase=${phase} status=${res.status}`);
    return valid ? body : null;
  }

  function row(body, expected, operation) {
    const ok = check(body, { [`${operation}: ID and persisted values`]: (b) => b && b.data.length === 1 &&
      typeof b.data[0].customer_id === 'string' && b.data[0].customer_id.length > 0 && b.data[0].customer_id.length <= 36 &&
      Object.keys(expected).every((key) => b.data[0][key] === expected[key] ||
        (key === 'is_active' && typeof b.data[0][key] === 'boolean' &&
          b.data[0][key] === (expected[key] === 1))) });
    return ok ? body.data[0] : null;
  }

  function payload(runId, suffix) {
    return { customer_name: `k6-${runId}-${suffix}`.slice(0, 100),
      email: `k6-${runId}-${suffix}@example.com`.slice(0, 100), phone_number: '081234567890',
      address_line1: 'k6 test address', address_line2: '', city: 'Jakarta', state: 'DKI Jakarta',
      postal_code: '00123', country: 'Indonesia', notes: `k6-owned:${runId}`, is_active: 1 };
  }

  function create(runId, suffix, phase) {
    const input = payload(runId, suffix);
    const body = request('POST', '', input, phase, 'create', 201);
    const record = row(body, input, 'create');
    return record ? { id: record.customer_id, input } : null;
  }

  function verify(record, expected, phase = 'verify') {
    return !!row(request('GET', record.id, null, phase, 'verify'),
      { ...expected, customer_id: record.id }, 'verify');
  }

  function remove(record) {
    if (!cleanup || !record) return true;
    // Confirm ownership again; never delete an unrelated record on a bad POST ID.
    const owner = row(request('GET', record.id, null, 'cleanup', 'cleanup_ownership'),
      { customer_id: record.id, notes: record.input.notes }, 'cleanup_ownership');
    if (!owner || !check(owner, { 'cleanup: owned test marker': (r) =>
      r.notes.startsWith('k6-owned:') && r.customer_name.startsWith('k6-') })) return false;
    const deleted = request('DELETE', record.id, null, 'cleanup', 'cleanup');
    const missing = deleted && request('GET', record.id, null, 'cleanup', 'deleted_readback', 404);
    return !!missing;
  }

  function read(id, phase = 'load') {
    const body = request('GET', '', null, phase, 'read_list');
    let ok = check(body, { 'read_list: nonempty public IDs': (b) => b && b.data.length > 0 &&
      b.data.every((item) => typeof item.customer_id === 'string' && item.customer_id.length > 0) });
    const detailId = id || (ok ? body.data[0].customer_id : '');
    if (!detailId) return false;
    ok = !!row(request('GET', detailId, null, phase, 'read_detail'), { customer_id: detailId }, 'read_detail') && ok;
    return ok;
  }

  function insert(data, fullFlow) {
    const suffix = `${exec.vu.idInTest}-${exec.vu.iterationInScenario}`;
    const record = create(data.runId, suffix, 'load');
    if (!record) return false;
    let ok = false;
    let cleaned = true;
    try {
      ok = verify(record, record.input);
      if (fullFlow && ok) ok = update(record);
    } finally { cleaned = remove(record); }
    return ok && cleaned;
  }

  function update(record) {
    const change = { city: `k6-city-${exec.vu.iterationInScenario}`, notes: record.input.notes,
      customer_name: `${record.input.customer_name}-updated`.slice(0, 100) };
    const updated = row(request('PUT', record.id, change, 'load', 'update'),
      { ...record.input, ...change, customer_id: record.id }, 'update');
    return !!updated && verify(record, { ...record.input, ...change });
  }

  function setup() {
    const data = { runId: __ENV.RUN_ID || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 9)}`, seeds: [] };
    console.log(`Workload=${mode}; run_id=${data.runId}; VUs=${vus}; cleanup=${cleanup}; result files stay local.`);
    if (!writes) {
      if (!read('', 'setup')) throw new Error('Read preflight failed; existing Customer data is required.');
      return data;
    }
    if (mode === 'update' || mode === 'mixed') {
      try {
        for (let i = 0; i < vus; i++) {
          const record = create(data.runId, `seed-${i + 1}`, 'setup');
          if (!record) throw new Error('Failed to create an owned update fixture.');
          data.seeds.push(record);
          if (!verify(record, record.input, 'setup')) throw new Error('Update fixture readback failed.');
        }
      } catch (error) {
        for (const record of data.seeds) remove(record);
        throw error;
      }
    }
    return data;
  }

  function run(data) {
    let kind = mode;
    if (mode === 'mixed') {
      const slot = exec.scenario.iterationInTest % 100;
      kind = slot < readWeight ? 'read' : slot < readWeight + writeWeight ? 'write' : 'update';
    }
    operations.add(1, { kind });
    let ok = false;
    try {
      if (kind === 'read') ok = read('');
      else if (kind === 'write' || kind === 'full-flow') ok = insert(data, kind === 'full-flow');
      else {
        const record = data.seeds[exec.vu.idInTest - 1];
        if (!record) throw new Error('No owned fixture for this VU; run on one local k6 instance.');
        ok = update(record);
      }
    } finally {
      completed.add(ok);
      if (pause) sleep(pause);
    }
  }

  function teardown(data) {
    if (data) for (const record of data.seeds) remove(record);
  }
  return { options, setup, run, teardown };
}
