const db = require('./database');

const sampleItems = [
  {
    name: 'Whole Milk 1 Gallon',
    category: 'Dairy',
    price: 3.49,
    quantity: 4,
    reorder_threshold: 10,
    order_status: 'NONE',
    expected_date: null
  },
  {
    name: 'Cheddar Cheese Block',
    category: 'Dairy',
    price: 4.99,
    quantity: 25,
    reorder_threshold: 8,
    order_status: 'NONE',
    expected_date: null
  },
  {
    name: 'Sourdough Bread Loaf',
    category: 'Bakery',
    price: 4.25,
    quantity: 0,
    reorder_threshold: 5,
    order_status: 'NONE',
    expected_date: null
  },
  {
    name: 'Croissants 4-Pack',
    category: 'Bakery',
    price: 3.99,
    quantity: 12,
    reorder_threshold: 6,
    order_status: 'NONE',
    expected_date: null
  },
  {
    name: 'Cold Brew Coffee 32oz',
    category: 'Beverages',
    price: 5.50,
    quantity: 3,
    reorder_threshold: 8,
    order_status: 'NONE',
    expected_date: null
  },
  {
    name: 'Sparkling Water 12-Pack',
    category: 'Beverages',
    price: 6.99,
    quantity: 20,
    reorder_threshold: 10,
    order_status: 'NONE',
    expected_date: null
  }
];

function seed() {
  console.log('Seeding sample items...');

  const insertStmt = db.prepare(`
    INSERT OR IGNORE INTO items (name, category, price, quantity, reorder_threshold, order_status, expected_date)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  let insertedCount = 0;
  let skippedCount = 0;

  const checkStmt = db.prepare('SELECT id FROM items WHERE name = ?');

  const runSeeding = db.transaction(() => {
    for (const item of sampleItems) {
      const exists = checkStmt.get(item.name);
      if (exists) {
        skippedCount++;
      } else {
        insertStmt.run(
          item.name,
          item.category,
          item.price,
          item.quantity,
          item.reorder_threshold,
          item.order_status,
          item.expected_date
        );
        insertedCount++;
      }
    }
  });

  runSeeding();

  console.log(`Seeding complete: ${insertedCount} items inserted, ${skippedCount} items skipped.`);
}

if (require.main === module) {
  seed();
}

module.exports = seed;
