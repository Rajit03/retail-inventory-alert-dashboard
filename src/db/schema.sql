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
