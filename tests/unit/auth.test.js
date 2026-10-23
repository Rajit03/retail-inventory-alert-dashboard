const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

const { hashPassword, comparePassword, hashPasswordSync, comparePasswordSync } = require('../../src/auth/hash');
const { can, PERMISSIONS } = require('../../src/auth/permissions');
const { resetLoginLimiter } = require('../../src/auth/limiter');

describe('Authentication and Authorization Unit Tests', () => {
  let server;
  let baseUrl;
  const tempDbPath = path.resolve(__dirname, '../../data/auth_unit_test.db');

  const DUMMY_PASSWORDS = {
    manager: 'TestDummyManagerPass123!',
    staff: 'TestDummyStaffPass123!',
    purchasing: 'TestDummyPurchasingPass123!'
  };

  before(async () => {
    process.env.NODE_ENV = 'test';
    process.env.DB_PATH = tempDbPath;
    process.env.SESSION_SECRET = 'unit-test-session-secret-key-32chars';
    process.env.SEED_MANAGER_PASSWORD = DUMMY_PASSWORDS.manager;
    process.env.SEED_STAFF_PASSWORD = DUMMY_PASSWORDS.staff;
    process.env.SEED_PURCHASING_PASSWORD = DUMMY_PASSWORDS.purchasing;

    if (fs.existsSync(tempDbPath)) {
      try { fs.unlinkSync(tempDbPath); } catch (_) {}
    }

    const app = require('../../src/app');
    const db = require('../../src/db/database');
    const { seedUsers } = require('../../src/auth/db');

    // Ensure users table in the active db has the test dummy credentials
    try {
      db.prepare('DELETE FROM users').run();
      seedUsers(db);
    } catch (_) {}

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });


  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    try {
      if (fs.existsSync(tempDbPath)) fs.unlinkSync(tempDbPath);
      const walFile = `${tempDbPath}-wal`;
      if (fs.existsSync(walFile)) fs.unlinkSync(walFile);
      const shmFile = `${tempDbPath}-shm`;
      if (fs.existsSync(shmFile)) fs.unlinkSync(shmFile);
    } catch (_) {}
  });

  // Helper to log in via API
  async function apiLogin(username, password) {
    const res = await fetch(`${baseUrl}/api/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    const status = res.status;
    const body = await res.json();
    let cookie = '';
    const rawCookies = res.headers.getSetCookie ? res.headers.getSetCookie() : [res.headers.get('set-cookie')];
    if (rawCookies && rawCookies.length > 0 && rawCookies[0]) {
      cookie = rawCookies.map(c => c.split(';')[0]).join('; ');
    }
    return { status, body, cookie, csrfToken: body.csrfToken };
  }

  // 1. Password hashing and verification
  describe('Password Hashing and Verification', () => {
    it('hashes password and verifies successfully with bcryptjs', async () => {
      const password = 'SecretPassword123!';
      const hash = await hashPassword(password);
      assert.notStrictEqual(hash, password);
      assert.ok(hash.startsWith('$2'));

      const isMatch = await comparePassword(password, hash);
      assert.strictEqual(isMatch, true);

      const isNotMatch = await comparePassword('WrongPassword', hash);
      assert.strictEqual(isNotMatch, false);
    });

    it('synchronous hash and compare work correctly', () => {
      const password = 'SyncPassword123!';
      const hash = hashPasswordSync(password);
      assert.ok(hash.startsWith('$2'));
      assert.strictEqual(comparePasswordSync(password, hash), true);
      assert.strictEqual(comparePasswordSync('WrongPassword', hash), false);
    });
  });

  // 2. can(role, action) for all roles and actions
  describe('can(role, action) Permissions Matrix', () => {
    const actions = ['items:write', 'transactions:write', 'orders:update', 'items:read', 'transactions:read', 'alerts:read'];

    it('manager can perform all actions including undefined actions', () => {
      for (const action of actions) {
        assert.strictEqual(can('manager', action), true, `manager should have ${action}`);
      }
      assert.strictEqual(can('manager', 'any:custom:action'), true);
    });

    it('staff can write items, write transactions, and update orders', () => {
      assert.strictEqual(can('staff', 'items:write'), true);
      assert.strictEqual(can('staff', 'transactions:write'), true);
      assert.strictEqual(can('staff', 'orders:update'), true);
      assert.strictEqual(can('staff', 'items:read'), true);
      assert.strictEqual(can('staff', 'transactions:read'), true);
      assert.strictEqual(can('staff', 'alerts:read'), true);
      assert.strictEqual(can('staff', 'admin:super'), false);
    });

    it('purchasing can update orders and view, but cannot write items or transactions', () => {
      assert.strictEqual(can('purchasing', 'orders:update'), true);
      assert.strictEqual(can('purchasing', 'items:read'), true);
      assert.strictEqual(can('purchasing', 'transactions:read'), true);
      assert.strictEqual(can('purchasing', 'alerts:read'), true);
      assert.strictEqual(can('purchasing', 'items:write'), false);
      assert.strictEqual(can('purchasing', 'transactions:write'), false);
      assert.strictEqual(can('purchasing', 'admin:super'), false);
    });

    it('unknown role or missing inputs return false', () => {
      assert.strictEqual(can('guest', 'items:read'), false);
      assert.strictEqual(can(null, 'items:read'), false);
      assert.strictEqual(can('manager', null), false);
      assert.strictEqual(can('', ''), false);
    });
  });

  // 3. Unauthenticated /api/items -> 401
  describe('Endpoint Protection & Public Access', () => {
    it('GET /api/items unauthenticated returns 401', async () => {
      const res = await fetch(`${baseUrl}/api/items`);
      assert.strictEqual(res.status, 401);
      const data = await res.json();
      assert.strictEqual(data.error, 'Authentication required');
    });

    // 12. /health stays public
    it('GET /health stays public (returns 200 without auth)', async () => {
      const res = await fetch(`${baseUrl}/health`);
      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.deepStrictEqual(data, { status: 'UP' });
    });

    // 13. Redirect of an HTML page to /login with next
    it('Unauthenticated GET /items redirects to /login?next=%2Fitems', async () => {
      const res = await fetch(`${baseUrl}/items`, { redirect: 'manual' });
      assert.strictEqual(res.status, 302);
      const location = res.headers.get('location');
      assert.ok(location.includes('/login?next='), `Expected redirect to /login?next=, got ${location}`);
      assert.ok(location.includes(encodeURIComponent('/items')) || location.includes('/items'));
    });
  });

  // 4. Wrong password -> 401 with same message for unknown user
  // 5. Correct login -> 200 and cookie
  describe('Authentication Flows', () => {
    it('wrong password returns 401 with same message as unknown user', async () => {
      resetLoginLimiter();

      const resUnknown = await fetch(`${baseUrl}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: 'nonexistent_user', password: 'password123' })
      });
      assert.strictEqual(resUnknown.status, 401);
      const bodyUnknown = await resUnknown.json();
      assert.strictEqual(bodyUnknown.error, 'Invalid username or password');

      const resWrongPass = await fetch(`${baseUrl}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: 'manager', password: 'incorrect_password' })
      });
      assert.strictEqual(resWrongPass.status, 401);
      const bodyWrongPass = await resWrongPass.json();
      assert.strictEqual(bodyWrongPass.error, 'Invalid username or password');
      assert.deepStrictEqual(bodyUnknown, bodyWrongPass);

      resetLoginLimiter();
    });

    it('correct login returns 200, session cookie, and csrfToken', async () => {
      const login = await apiLogin('manager', DUMMY_PASSWORDS.manager);
      assert.strictEqual(login.status, 200);
      assert.strictEqual(login.body.username, 'manager');
      assert.strictEqual(login.body.role, 'manager');
      assert.ok(login.body.csrfToken);
      assert.ok(login.cookie.includes('session='));
    });
  });

  // 6. Purchasing creating an item -> 403
  // 7. Purchasing updating order status -> allowed
  // 8. Staff creating an item -> allowed
  // 10. Missing CSRF token on a POST -> 403
  describe('Role-Based Authorization and CSRF Protection', () => {
    let purchasingSession;
    let staffSession;
    let createdItemId;

    before(async () => {
      purchasingSession = await apiLogin('purchasing', DUMMY_PASSWORDS.purchasing);
      staffSession = await apiLogin('staff', DUMMY_PASSWORDS.staff);
      assert.strictEqual(purchasingSession.status, 200);
      assert.strictEqual(staffSession.status, 200);
    });

    it('purchasing role creating an item returns 403', async () => {
      const res = await fetch(`${baseUrl}/api/items`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Cookie: purchasingSession.cookie,
          'x-csrf-token': purchasingSession.csrfToken
        },
        body: JSON.stringify({
          name: 'Purchasing Forbidden Item',
          category: 'Test',
          price: 9.99,
          quantity: 10,
          reorder_threshold: 5
        })
      });
      assert.strictEqual(res.status, 403);
    });

    it('staff role creating an item is allowed (returns 201)', async () => {
      const res = await fetch(`${baseUrl}/api/items`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Cookie: staffSession.cookie,
          'x-csrf-token': staffSession.csrfToken
        },
        body: JSON.stringify({
          name: 'Staff Created Item',
          category: 'Test',
          price: 19.99,
          quantity: 20,
          reorder_threshold: 5
        })
      });
      assert.strictEqual(res.status, 201);
      const item = await res.json();
      createdItemId = item.id;
      assert.strictEqual(item.name, 'Staff Created Item');
    });

    it('purchasing role updating order status is allowed', async () => {
      assert.ok(createdItemId, 'createdItemId must exist');
      const res = await fetch(`${baseUrl}/api/items/${createdItemId}/order-status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Cookie: purchasingSession.cookie,
          'x-csrf-token': purchasingSession.csrfToken
        },
        body: JSON.stringify({
          order_status: 'ORDERED',
          expected_date: '2026-12-31'
        })
      });
      assert.strictEqual(res.status, 200);
      const updated = await res.json();
      assert.strictEqual(updated.order_status, 'ORDERED');
      assert.strictEqual(updated.expected_date, '2026-12-31');
    });

    it('missing CSRF token on a POST returns 403', async () => {
      const res = await fetch(`${baseUrl}/api/items`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Cookie: staffSession.cookie
          // Note: x-csrf-token omitted
        },
        body: JSON.stringify({
          name: 'No CSRF Item',
          category: 'Test',
          price: 5.99,
          quantity: 10,
          reorder_threshold: 2
        })
      });
      assert.strictEqual(res.status, 403);
      const data = await res.json();
      assert.ok(data.error && data.error.includes('CSRF'));
    });
  });

  // 11. Rate limit -> 429 after 5 failed logins
  describe('Login Rate Limiter', () => {
    it('returns 429 after 5 failed login attempts', async () => {
      resetLoginLimiter();

      for (let i = 1; i <= 5; i++) {
        const res = await fetch(`${baseUrl}/api/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: 'manager', password: `wrong_${i}` })
        });
        assert.strictEqual(res.status, 401, `Attempt ${i} should return 401`);
      }

      // 6th attempt should be blocked by rate limit
      const blockedRes = await fetch(`${baseUrl}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: 'manager', password: 'wrong_6' })
      });
      assert.strictEqual(blockedRes.status, 429, '6th attempt should return 429');
      const blockedBody = await blockedRes.json();
      assert.ok(blockedBody.error && blockedBody.error.includes('Too many failed login attempts'));

      resetLoginLimiter();
    });
  });
});
