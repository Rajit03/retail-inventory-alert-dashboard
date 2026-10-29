const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

describe('API Smoke Tests', () => {
  let server;
  let baseUrl;
  let authCookie;
  let csrfToken;
  const tempDbPath = path.resolve(__dirname, '../../data/smoke_test.db');

  before(async () => {
    // Set test-only environment before loading database and app
    process.env.NODE_ENV = 'test';
    process.env.DB_PATH = tempDbPath;
    process.env.SESSION_SECRET = 'test-session-secret-smoke-test-1234';
    process.env.SEED_MANAGER_PASSWORD = 'TestManagerPassword123!';
    process.env.SEED_STAFF_PASSWORD = 'TestStaffPassword123!';

    // Delete pre-existing test DB if any
    if (fs.existsSync(tempDbPath)) {
      try { fs.unlinkSync(tempDbPath); } catch (_) {}
    }

    const app = require('../../src/app');

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });

    // Log in as manager to get session cookie and csrfToken for protected API endpoints
    const loginRes = await fetch(`${baseUrl}/api/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'manager',
        password: 'TestManagerPassword123!'
      })
    });
    assert.strictEqual(loginRes.status, 200);
    const loginData = await loginRes.json();
    csrfToken = loginData.csrfToken;

    const rawCookies = loginRes.headers.getSetCookie
      ? loginRes.headers.getSetCookie()
      : [loginRes.headers.get('set-cookie')];
    authCookie = rawCookies.map(c => c.split(';')[0]).join('; ');
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    // Clean up temporary database files
    try {
      if (fs.existsSync(tempDbPath)) fs.unlinkSync(tempDbPath);
      const walFile = `${tempDbPath}-wal`;
      if (fs.existsSync(walFile)) fs.unlinkSync(walFile);
      const shmFile = `${tempDbPath}-shm`;
      if (fs.existsSync(shmFile)) fs.unlinkSync(shmFile);
    } catch (_) {}
  });

  it('GET /health returns 200 and {"status":"UP"}', async () => {
    const res = await fetch(`${baseUrl}/health`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.deepStrictEqual(body, { status: 'UP' });
  });

  it('GET /api/items returns 200 and a JSON array', async () => {
    const res = await fetch(`${baseUrl}/api/items`, {
      headers: { Cookie: authCookie }
    });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.ok(Array.isArray(body));
  });

  it('POST /api/items with an empty name returns 400', async () => {
    const res = await fetch(`${baseUrl}/api/items`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Cookie: authCookie,
        'x-csrf-token': csrfToken
      },
      body: JSON.stringify({
        name: '',
        category: 'Test',
        price: 10,
        quantity: 5,
        reorder_threshold: 2
      })
    });
    assert.strictEqual(res.status, 400);
    const body = await res.json();
    assert.ok(body.errors && body.errors.length > 0);
  });

  it('GET /api/alerts returns 200', async () => {
    const res = await fetch(`${baseUrl}/api/alerts`, {
      headers: { Cookie: authCookie }
    });
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.ok(Array.isArray(body));
  });
});
