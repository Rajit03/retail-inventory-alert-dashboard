const express = require('express');
const router = express.Router();
const db = require('../db/database');
const validateItem = require('../validators/itemValidator');

// GET /api/items - list all items
router.get('/', (req, res) => {
  try {
    const items = db.prepare('SELECT * FROM items ORDER BY id ASC').all();
    res.json(items);
  } catch (err) {
    res.status(500).json({ error: 'Failed to retrieve items' });
  }
});

// GET /api/items/:id - get single item by id
router.get('/:id', (req, res) => {
  try {
    const item = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }
    res.json(item);
  } catch (err) {
    res.status(500).json({ error: 'Failed to retrieve item' });
  }
});

// POST /api/items - create a new item
router.post('/', (req, res) => {
  const errors = validateItem(req.body);
  if (errors.length > 0) {
    return res.status(400).json({ errors });
  }

  const { name, category, price, quantity, reorder_threshold, order_status, expected_date } = req.body;

  try {
    const existing = db.prepare('SELECT id FROM items WHERE name = ?').get(name.trim());
    if (existing) {
      return res.status(409).json({ error: 'An item with this name already exists' });
    }

    const insert = db.prepare(`
      INSERT INTO items (name, category, price, quantity, reorder_threshold, order_status, expected_date)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);

    const result = insert.run(
      name.trim(),
      category.trim(),
      Number(price),
      Number(quantity),
      Number(reorder_threshold),
      order_status || 'NONE',
      expected_date || null
    );

    const newItem = db.prepare('SELECT * FROM items WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(newItem);
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || (err.message && err.message.includes('UNIQUE'))) {
      return res.status(409).json({ error: 'An item with this name already exists' });
    }
    res.status(500).json({ error: 'Failed to create item' });
  }
});

// PUT /api/items/:id - update an existing item
router.put('/:id', (req, res) => {
  try {
    const existingItem = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    if (!existingItem) {
      return res.status(404).json({ error: 'Item not found' });
    }

    const errors = validateItem(req.body);
    if (errors.length > 0) {
      return res.status(400).json({ errors });
    }

    const { name, category, price, quantity, reorder_threshold, order_status, expected_date } = req.body;

    const duplicate = db.prepare('SELECT id FROM items WHERE name = ? AND id != ?').get(name.trim(), req.params.id);
    if (duplicate) {
      return res.status(409).json({ error: 'An item with this name already exists' });
    }

    const update = db.prepare(`
      UPDATE items
      SET name = ?, category = ?, price = ?, quantity = ?, reorder_threshold = ?, order_status = ?, expected_date = ?
      WHERE id = ?
    `);

    update.run(
      name.trim(),
      category.trim(),
      Number(price),
      Number(quantity),
      Number(reorder_threshold),
      order_status !== undefined ? order_status : existingItem.order_status,
      expected_date !== undefined ? expected_date : existingItem.expected_date,
      req.params.id
    );

    const updatedItem = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    res.status(200).json(updatedItem);
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || (err.message && err.message.includes('UNIQUE'))) {
      return res.status(409).json({ error: 'An item with this name already exists' });
    }
    res.status(500).json({ error: 'Failed to update item' });
  }
});

module.exports = router;
