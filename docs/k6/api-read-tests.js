import http from 'k6/http';
import { check, group, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:9999';
const API_TOKEN = __ENV.API_TOKEN || '';

const USER_ID = __ENV.USER_ID || '46b98046-ce79-4a00-9e27-1353c8de401a';
const PRODUCT_ID = __ENV.PRODUCT_ID || '550e8400-e29b-41d4-a716-446655441003';
const CATEGORY_ID = __ENV.CATEGORY_ID || '550e8400-e29b-41d4-a716-446655440444';

const PARAMS = {
  headers: {
    'Content-Type': 'application/json',
    'x-api-token': API_TOKEN,
  },
};

export const options = {
  stages: [
    { duration: '15s', target: 5 },
    { duration: '15s', target: 10 },
    { duration: '15s', target: 15 },
    { duration: '15s', target: 25 },
    // { duration: '15s', target: 40 },
    // { duration: '30s', target: 50 },
    { duration: '15s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
  noConnectionReuse: false,
  noVUConnectionReuse: false,
};

const ENDPOINTS = [
  {
    groupName: 'Users',
    name: 'Get All Users',
    url: '/api/v1/User',
    expectedStatus: 200,
  },
  {
    groupName: 'Users',
    name: 'Get User by ID',
    url: `/api/v1/User/${USER_ID}`,
    expectedStatus: 200,
  },
  {
    groupName: 'Products',
    name: 'Get All Products',
    url: '/api/v1/Product',
    expectedStatus: 200,
  },
  {
    groupName: 'Products',
    name: 'Get Product by ID',
    url: `/api/v1/Product/${PRODUCT_ID}`,
    expectedStatus: 200,
  },
  {
    groupName: 'Categories',
    name: 'Get All Categories',
    url: '/api/v1/Category',
    expectedStatus: 200,
  },
  {
    groupName: 'Categories',
    name: 'Get Category by ID',
    url: `/api/v1/Category/${CATEGORY_ID}`,
    expectedStatus: 200,
  },
];

function tryParseJson(res) {
  try {
    return JSON.parse(res.body);
  } catch (e) {
    return null;
  }
}

function validateSuccessResponse(res, expectedStatus, label) {
  check(res, {
    [`${label} - status is ${expectedStatus}`]: (r) => r.status === expectedStatus,
  });

  if (res.status !== expectedStatus) {
    return null;
  }

  const body = tryParseJson(res);

  check(body, {
    [`${label} - body is valid json`]: (b) => b !== null,
    [`${label} - json status field matches`]: (b) => b && b.status === expectedStatus,
    [`${label} - messages field exists`]: (b) => b && b.messages !== undefined,
    [`${label} - servertime field exists`]: (b) => b && b.servertime !== undefined,
    [`${label} - data is an array`]: (b) => b && Array.isArray(b.data),
  });

  return body;
}

function runEndpoint(endpoint) {
  group(endpoint.groupName, function () {
    group(endpoint.name, function () {
      const res = http.get(`${BASE_URL}${endpoint.url}`, PARAMS);
      validateSuccessResponse(res, endpoint.expectedStatus, endpoint.name);

      // Small delay to reduce socket pressure on localhost/Windows.
      sleep(0.05);
    });
  });
}

export default function () {
  // Randomize start index so all VUs don't hit the same endpoint at exactly the same pattern.
  const startIndex = Math.floor(Math.random() * ENDPOINTS.length);

  for (let i = 0; i < ENDPOINTS.length; i++) {
    const endpoint = ENDPOINTS[(startIndex + i) % ENDPOINTS.length];
    runEndpoint(endpoint);
  }

  // Think time per iteration.
  // This prevents every VU from looping brutally with no pause.
  sleep(0.2);
}