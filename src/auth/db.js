const { hashPasswordSync } = require('./hash');

function migrateUsers(db) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('manager', 'staff', 'purchasing')),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);
}

function seedUsers(db) {
  const countRow = db.prepare('SELECT COUNT(*) AS count FROM users').get();
  if (countRow.count > 0) {
    return;
  }

  const mgrPass = process.env.SEED_MANAGER_PASSWORD;
  const staffPass = process.env.SEED_STAFF_PASSWORD;
  const purchPass = process.env.SEED_PURCHASING_PASSWORD;

  const validMgr = typeof mgrPass === 'string' && mgrPass.length >= 10;
  const validStaff = typeof staffPass === 'string' && staffPass.length >= 10;
  const validPurch = typeof purchPass === 'string' && purchPass.length >= 10;

  if (validMgr && validStaff && validPurch) {
    const insert = db.prepare('INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)');
    const seedTx = db.transaction(() => {
      insert.run('manager', hashPasswordSync(mgrPass), 'manager');
      insert.run('staff', hashPasswordSync(staffPass), 'staff');
      insert.run('purchasing', hashPasswordSync(purchPass), 'purchasing');
    });
    seedTx();
    console.log('Seeded default users (manager, staff, purchasing).');
  } else {
    console.warn(
      'Warning: Users table is empty but default users were not seeded. ' +
      'SEED_MANAGER_PASSWORD, SEED_STAFF_PASSWORD, and SEED_PURCHASING_PASSWORD must all be defined with at least 10 characters.'
    );
  }
}

function migrateAndSeedUsers(db) {
  migrateUsers(db);
  seedUsers(db);
}

function getUserByUsername(db, username) {
  if (!username) return null;
  return db.prepare('SELECT * FROM users WHERE username = ?').get(username);
}

module.exports = {
  migrateUsers,
  seedUsers,
  migrateAndSeedUsers,
  getUserByUsername
};
