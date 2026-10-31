import http from 'k6/http';
import { check, group, sleep } from 'k6';

// Read-only coverage: GET list/detail for User, Product, Category, Customer.
// Source: BFA.Core.Rest.RegisterClassAPI, each module's Service.Get and Repository.Get*.
// Optional: GET /image?filename=... (App.WebModule.WMimageAction).
// Auth Login/Refresh/Logout and password/CRUD writes are excluded from this read test.
// The HTML root and /test debug handler are not data API endpoints.
//
// PowerShell:
//   $env:API_TOKEN = '<valid access token from Auth/Login>'
//   k6 run -e BASE_URL=http://127.0.0.1:9999 docs/k6/api-read-test-all.js
// Smoke (1 VU, 1 iteration):
//   k6 run -e SMOKE=1 docs/k6/api-read-test-all.js
// Optional: -e USER_ID=... -e PRODUCT_ID=... -e CATEGORY_ID=... -e CUSTOMER_ID=...
// Otherwise setup discovers the first public ID from each list, without creating data.
// Optional image: -e IMAGE_FILENAME=existing-image.png
// All four resources must contain data; empty lists return 404 in the current services.
// Use x-api-token: the current Indy bridge rejects Bearer before API token validation.
// The API still validates this token against active access_token/user_session records.
// Customer benchmark: -e RESOURCE=Customer -e FIXED_VUS=5 -e TEST_DURATION=60s
// Isolate list/detail load: -e ENDPOINT=list (default: all; detail still discovers its ID in setup).
// Optional fixture checks: -e EXPECTED_CUSTOMER_ROWS=2300 (also USER, PRODUCT, CATEGORY).
// Compression A/B: -e RESPONSE_ENCODING=gzip or identity (default: auto).
// Keep the same options for before/after runs; defaults retain the seven-stage profile.

const BASE_URL = (__ENV.BASE_URL || 'http://127.0.0.1:9999').replace(/\/+$/, '');
const API_TOKEN = (__ENV.API_TOKEN || '').trim();
const IMAGE_FILENAME = (__ENV.IMAGE_FILENAME || '').trim();
const RESPONSE_ENCODING = (__ENV.RESPONSE_ENCODING || 'auto').trim().toLowerCase();
if (!['auto', 'gzip', 'identity'].includes(RESPONSE_ENCODING)) {
  throw new Error('RESPONSE_ENCODING must be auto, gzip, or identity.');
}

const ALL_RESOURCES = [
  { name: 'User', groupName: 'Users', idField: 'user_id', id: __ENV.USER_ID },
  { name: 'Product', groupName: 'Products', idField: 'product_id', id: __ENV.PRODUCT_ID },
  { name: 'Category', groupName: 'Categories', idField: 'category_id', id: __ENV.CATEGORY_ID },
  { name: 'Customer', groupName: 'Customers', idField: 'customer_id', id: __ENV.CUSTOMER_ID },
].map((resource) => ({ ...resource, expectedRows: expectedRows(resource.name) }));

function expectedRows(resourceName) {
  const envName = `EXPECTED_${resourceName.toUpperCase()}_ROWS`;
  if (__ENV[envName] === undefined) return undefined;

  const value = Number(__ENV[envName]);
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new Error(`${envName} must be a positive safe integer; empty lists are not supported by this read test.`);
  }
  return value;
}

const RESOURCE = (__ENV.RESOURCE || '').trim();
const RESOURCES = RESOURCE
  ? ALL_RESOURCES.filter((resource) => resource.name.toLowerCase() === RESOURCE.toLowerCase())
  : ALL_RESOURCES;
if (RESOURCES.length === 0) throw new Error('RESOURCE must be User, Product, Category, or Customer.');

const ENDPOINT = (__ENV.ENDPOINT || 'all').trim().toLowerCase();
if (!['all', 'list', 'detail'].includes(ENDPOINT)) {
  throw new Error('ENDPOINT must be all, list, or detail.');
}

const FIXED_VUS = __ENV.FIXED_VUS === undefined ? 0 : Number(__ENV.FIXED_VUS);
if (__ENV.FIXED_VUS !== undefined && (!Number.isInteger(FIXED_VUS) || FIXED_VUS < 1)) {
  throw new Error('FIXED_VUS must be a positive integer.');
}

const thresholds = {
  checks: ['rate==1'],
  http_req_failed: ['rate<0.01'],
  http_req_duration: ['p(95)<500'],
};
function addEndpointThresholds(key) {
  const tags = `phase:load,endpoint:${key}`;
  thresholds[`http_req_duration{${tags}}`] = ['p(95)<500'];
  thresholds[`http_req_failed{${tags}}`] = ['rate<0.01'];
  thresholds[`http_reqs{${tags}}`] = ['count>0'];
}
for (const resource of RESOURCES) {
  if (ENDPOINT !== 'detail') addEndpointThresholds(`${resource.name}_list`);
  if (ENDPOINT !== 'list') addEndpointThresholds(`${resource.name}_detail`);
}
if (IMAGE_FILENAME) addEndpointThresholds('Image');

export const options = {
  ...(__ENV.SMOKE === '1'
    ? { vus: 1, iterations: 1 }
    : FIXED_VUS > 0
      ? { vus: FIXED_VUS, duration: __ENV.TEST_DURATION || '60s' }
      : {
          stages: [
            { duration: '15s', target: 5 },
            { duration: '15s', target: 10 },
            { duration: '15s', target: 15 },
            { duration: '15s', target: 25 },
            { duration: '15s', target: 30 },
            { duration: '15s', target: 35 },
            { duration: '15s', target: 0 },
          ],
        }),
  thresholds,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
  setupTimeout: '5m',
  noConnectionReuse: false,
  noVUConnectionReuse: false,
};

function requestParams(endpoint, phase) {
  const headers = endpoint.image
    ? { Accept: 'image/*' }
    : { Accept: 'application/json', 'x-api-token': API_TOKEN };
  if (RESPONSE_ENCODING !== 'auto') headers['Accept-Encoding'] = RESPONSE_ENCODING;
  return {
    headers,
    tags: { name: `GET ${endpoint.route}`, phase, endpoint: endpoint.key },
    timeout: '30s',
    redirects: 0,
    responseType: endpoint.image ? 'binary' : 'text',
    responseCallback: http.expectedStatuses(200),
  };
}

function tryParseJson(res) {
  try {
    return JSON.parse(res.body);
  } catch (e) {
    return null;
  }
}

function validateResponse(res, endpoint) {
  const label = endpoint.name;
  const statusOK = check(res, {
    [`${label} - HTTP status is 200`]: (r) => r.status === 200,
  });

  if (!statusOK) return null;

  if (endpoint.image) {
    const valid = check(res, {
      [`${label} - image content type matches filename`]: (r) =>
        String(r.headers['Content-Type'] || '').split(';')[0].trim().toLowerCase() ===
        endpoint.contentType,
      [`${label} - image body is not empty`]: (r) => r.body && r.body.byteLength > 0,
    });
    return valid ? res : null;
  }

  const body = tryParseJson(res);
  const valid = check(body, {
    [`${label} - body is a JSON object`]: (b) =>
      b !== null && typeof b === 'object' && !Array.isArray(b),
    [`${label} - JSON content type`]: () =>
      /^application\/json(?:\s*;|$)/i.test(res.headers['Content-Type'] || ''),
    [`${label} - envelope status matches HTTP status`]: (b) => b && b.status === res.status,
    [`${label} - messages is a string`]: (b) => b && typeof b.messages === 'string',
    [`${label} - servertime is a Unix timestamp`]: (b) =>
      b && /^\d+$/.test(String(b.servertime)) && Number(b.servertime) > 0,
    [`${label} - data is a non-empty array`]: (b) =>
      b && Array.isArray(b.data) && b.data.length > 0,
    [`${label} - records contain public IDs`]: (b) =>
      b && Array.isArray(b.data) && b.data.length > 0 &&
      b.data.every((row) => row && typeof row[endpoint.idField] === 'string' &&
        row[endpoint.idField].trim() !== ''),
  });

  if (!valid) return null;

  if (endpoint.expectedRows !== undefined && endpoint.expectedRows !== null && !check(body.data, {
    [`${label} - row count matches expected fixture`]: (rows) =>
      rows.length === endpoint.expectedRows,
  })) return null;

  if (endpoint.id && !check(body.data, {
    [`${label} - exactly one record with the requested ID`]: (rows) =>
      rows.length === 1 && rows[0][endpoint.idField] === endpoint.id,
  })) return null;

  return body;
}

function readEndpoint(endpoint, phase) {
  const res = http.get(`${BASE_URL}${endpoint.url}`, requestParams(endpoint, phase));
  const body = validateResponse(res, endpoint);
  if (phase === 'setup' && !body) {
    // Do not log response bodies, which can contain user/customer data.
    throw new Error(`${endpoint.name}: preflight failed (HTTP ${res.status}). ` +
      'Check API_TOKEN, existing data/IDs, and response checks before running load.');
  }
  return body;
}

export function setup() {
  if (!API_TOKEN) throw new Error('API_TOKEN is required. Supply a valid access token from Auth/Login.');

  let imageContentType = '';
  if (IMAGE_FILENAME) {
    const extension = IMAGE_FILENAME.split('.').pop().toLowerCase();
    imageContentType = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', bmp: 'image/bmp' }[extension];
    if (/[\\/]/.test(IMAGE_FILENAME) || !imageContentType) {
      throw new Error('IMAGE_FILENAME must be a filename ending in .jpg, .jpeg, .png, or .bmp.');
    }
  }

  const endpoints = [];
  for (const resource of RESOURCES) {
    const route = `/api/v1/${resource.name}`;
    const listEndpoint = {
      key: `${resource.name}_list`,
      groupName: resource.groupName,
      name: `Get All ${resource.groupName}`,
      route,
      url: route,
      idField: resource.idField,
      expectedRows: resource.expectedRows,
    };
    const body = readEndpoint(listEndpoint, 'setup');
    console.log(`${resource.name} preflight: list_rows=${body.data.length}`);
    const id = (resource.id || '').trim() || body.data[0][resource.idField];
    const detailEndpoint = {
      key: `${resource.name}_detail`,
      groupName: resource.groupName,
      name: `Get ${resource.name} by ID`,
      route: `${route}/{${resource.idField}}`,
      url: `${route}/${encodeURIComponent(id)}`,
      idField: resource.idField,
      id,
    };
    if (ENDPOINT !== 'list') readEndpoint(detailEndpoint, 'setup');
    if (ENDPOINT !== 'detail') endpoints.push(listEndpoint);
    if (ENDPOINT !== 'list') endpoints.push(detailEndpoint);
  }

  if (IMAGE_FILENAME) {
    const imageEndpoint = {
      key: 'Image',
      groupName: 'Images',
      name: 'Get Image',
      route: '/image',
      url: `/image?filename=${encodeURIComponent(IMAGE_FILENAME)}`,
      image: true,
      contentType: imageContentType,
    };
    readEndpoint(imageEndpoint, 'setup');
    endpoints.push(imageEndpoint);
  }

  console.log(`Preflight passed: ${endpoints.length} GET endpoints ready for read testing.`);
  if (!IMAGE_FILENAME) console.log('Image endpoint excluded: set IMAGE_FILENAME to test an existing image.');
  return { endpoints };
}

export default function (data) {
  // Rotate the first endpoint to spread concurrent requests across resources.
  const endpoints = data.endpoints;
  const startIndex = Math.floor(Math.random() * endpoints.length);
  for (let i = 0; i < endpoints.length; i++) {
    const endpoint = endpoints[(startIndex + i) % endpoints.length];
    group(endpoint.groupName, function () {
      group(endpoint.name, function () {
        readEndpoint(endpoint, 'load');
        sleep(0.05);
      });
    });
  }
  sleep(0.2);
}
