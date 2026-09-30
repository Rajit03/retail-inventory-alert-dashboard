const express = require('express');
const router = express.Router();
const db = require('../db/database');
const validateItem = require('../validators/itemValidator');
const getStockStatus = require('../utils/stockStatus');

// GET /items - catalogue table
router.get('/items', (req, res) => {
  try {
    const items = db.prepare('SELECT * FROM items ORDER BY id ASC').all();
    const itemsWithStatus = items.map(item => ({
      ...item,
      stock_status: getStockStatus(item)
    }));
    res.render('items/index', { items: itemsWithStatus });
  } catch (err) {
    res.status(500).send('Error loading items catalogue');
  }
});

// GET /items/new - add item form
router.get('/items/new', (req, res) => {
  res.render('items/new', { errors: [], item: {} });
});

// POST /items - create item
router.post('/items', (req, res) => {
  const errors = validateItem(req.body);
  const { name, category, price, quantity, reorder_threshold } = req.body;
  const itemData = { name, category, price, quantity, reorder_threshold };

  if (errors.length > 0) {
    return res.status(400).render('items/new', { errors, item: itemData });
  }

  try {
    const existing = db.prepare('SELECT id FROM items WHERE name = ?').get(name.trim());
    if (existing) {
      return res.status(409).render('items/new', {
        errors: ['An item with this name already exists.'],
        item: itemData,
      });
    }

    const insert = db.prepare(`
      INSERT INTO items (name, category, price, quantity, reorder_threshold, order_status, expected_date)
      VALUES (?, ?, ?, ?, ?, 'NONE', NULL)
    `);

    insert.run(
      name.trim(),
      category.trim(),
      Number(price),
      Number(quantity),
      Number(reorder_threshold)
    );

    res.redirect('/items');
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || (err.message && err.message.includes('UNIQUE'))) {
      return res.status(409).render('items/new', {
        errors: ['An item with this name already exists.'],
        item: itemData,
      });
    }
    res.status(500).render('items/new', {
      errors: ['Failed to save item. Please try again.'],
      item: itemData,
    });
  }
});

// GET /items/:id/edit - edit item form
router.get('/items/:id/edit', (req, res) => {
  try {
    const item = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    if (!item) {
      return res.status(404).send('Item not found');
    }
    res.render('items/edit', { errors: [], item });
  } catch (err) {
    res.status(500).send('Error loading item for edit');
  }
});

// POST /items/:id - update item
router.post('/items/:id', (req, res) => {
  const errors = validateItem(req.body);
  const { name, category, price, quantity, reorder_threshold, order_status, expected_date } = req.body;
  const itemData = {
    id: req.params.id,
    name,
    category,
    price,
    quantity,
    reorder_threshold,
    order_status: order_status || 'NONE',
    expected_date: expected_date || ''
  };

  if (order_status === 'ORDERED') {
    if (!expected_date || typeof expected_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(expected_date.trim())) {
      errors.push('Expected date is required in YYYY-MM-DD format when order status is ORDERED.');
    }
  }

  if (errors.length > 0) {
    return res.status(400).render('items/edit', { errors, item: itemData });
  }

  try {
    const existingItem = db.prepare('SELECT * FROM items WHERE id = ?').get(req.params.id);
    if (!existingItem) {
      return res.status(404).send('Item not found');
    }

    const duplicate = db.prepare('SELECT id FROM items WHERE name = ? AND id != ?').get(name.trim(), req.params.id);
    if (duplicate) {
      return res.status(409).render('items/edit', {
        errors: ['An item with this name already exists.'],
        item: itemData,
      });
    }

    let finalExpectedDate = null;
    const normStatus = order_status ? order_status.toUpperCase() : 'NONE';
    if (normStatus === 'ORDERED' && expected_date) {
      finalExpectedDate = expected_date.trim();
    } else if (normStatus === 'RECEIVED' && expected_date) {
      finalExpectedDate = expected_date.trim();
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
      normStatus,
      finalExpectedDate,
      req.params.id
    );

    res.redirect('/items');
  } catch (err) {
    if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || (err.message && err.message.includes('UNIQUE'))) {
      return res.status(409).render('items/edit', {
        errors: ['An item with this name already exists.'],
        item: itemData,
      });
    }
    res.status(500).render('items/edit', {
      errors: ['Failed to update item. Please try again.'],
      item: itemData,
    });
  }
});

module.exports = router;
