CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    price REAL NOT NULL DEFAULT 0 CHECK(price >= 0),
    quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
    reorder_threshold INTEGER NOT NULL DEFAULT 0 CHECK(reorder_threshold >= 0),
    order_status TEXT NOT NULL DEFAULT 'NONE',
    expected_date TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL REFERENCES items(id),
    type TEXT NOT NULL CHECK(type IN ('IN','OUT','ADJUST')),
    quantity INTEGER NOT NULL CHECK(quantity >= 0),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
