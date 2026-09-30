const express = require('express');
const router = express.Router();
const db = require('../db/database');
const validateItem = require('../validators/itemValidator');
const getStockStatus = require('../utils/stockStatus');

// GET /api/items - list all items
router.get('/', (req, res) => {
  try {
    const items = db.prepare('SELECT * FROM items ORDER BY id ASC').all();
    const itemsWithStatus = items.map(item => ({
      ...item,
      stock_status: getStockStatus(item)
    }));
    res.json(itemsWithStatus);
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
    res.json({
      ...item,
      stock_status: getStockStatus(item)
    });
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
    return res.status(200).json({
      ...updatedItem,
      stock_status: getStockStatus(updatedItem)
    });
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || (err.message && err.message.includes('UNIQUE'))) {
      return res.status(409).json({ error: 'An item with this name already exists' });
    }
    return res.status(500).json({ error: 'Failed to update item' });
  }
});

// PATCH /api/items/:id/order-status - update order status and expected date
router.patch('/:id/order-status', (req, res) => {
  try {
    const existingItem = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    if (!existingItem) {
      return res.status(404).json({ error: 'Item not found' });
    }

    const { order_status, expected_date } = req.body;
    const validStatuses = ['NONE', 'ORDERED', 'RECEIVED'];

    if (!order_status || !validStatuses.includes(order_status.toUpperCase())) {
      return res.status(400).json({
        errors: ["Order status must be one of: 'NONE', 'ORDERED', 'RECEIVED'."]
      });
    }

    const normStatus = order_status.toUpperCase();
    let finalExpectedDate = null;

    if (normStatus === 'ORDERED') {
      if (!expected_date || typeof expected_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(expected_date.trim())) {
        return res.status(400).json({
          errors: ['Expected date is required in YYYY-MM-DD format when order status is ORDERED.']
        });
      }
      finalExpectedDate = expected_date.trim();
    } else if (normStatus === 'RECEIVED' && expected_date) {
      finalExpectedDate = expected_date.trim();
    }

    db.prepare(`
      UPDATE items
      SET order_status = ?, expected_date = ?
      WHERE id = ?
    `).run(normStatus, finalExpectedDate, req.params.id);

    const updatedItem = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    return res.status(200).json({
      ...updatedItem,
      stock_status: getStockStatus(updatedItem)
    });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update order status' });
  }
});

module.exports = router;
