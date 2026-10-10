const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const fs = require('node:fs');

describe('API Smoke Tests', () => {
  let server;
  let baseUrl;
  const tempDbPath = path.resolve(__dirname, '../../data/smoke_test.db');

  before(async () => {
    // Set DB_PATH before loading database/app
    process.env.DB_PATH = tempDbPath;

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
    const res = await fetch(`${baseUrl}/api/items`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.ok(Array.isArray(body));
  });

  it('POST /api/items with an empty name returns 400', async () => {
    const res = await fetch(`${baseUrl}/api/items`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
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
    const res = await fetch(`${baseUrl}/api/alerts`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.ok(Array.isArray(body));
  });
});
