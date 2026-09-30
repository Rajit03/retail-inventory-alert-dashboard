const express = require('express');
const router = express.Router();
const db = require('../db/database');
const validateTransaction = require('../validators/transactionValidator');

// POST /api/transactions - create stock transaction
router.post('/api/transactions', (req, res) => {
  const errors = validateTransaction(req.body);
  if (errors.length > 0) {
    return res.status(400).json({ errors });
  }

  const itemId = req.body.item_id !== undefined ? Number(req.body.item_id) : Number(req.body.itemId);
  const type = req.body.type.toUpperCase();
  const quantity = Number(req.body.quantity);

  try {
    const item = db.prepare('SELECT * FROM items WHERE id = ?').get(itemId);
    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }

    let newQuantity;
    if (type === 'IN') {
      newQuantity = item.quantity + quantity;
    } else if (type === 'OUT') {
      if (quantity > item.quantity) {
        return res.status(400).json({
          errors: [`Cannot remove ${quantity} units. Available stock is ${item.quantity}.`]
        });
      }
      newQuantity = item.quantity - quantity;
    } else if (type === 'ADJUST') {
      newQuantity = quantity;
    }

    const executeTransaction = db.transaction(() => {
      db.prepare('UPDATE items SET quantity = ? WHERE id = ?').run(newQuantity, itemId);
      const insertResult = db.prepare(`
        INSERT INTO transactions (item_id, type, quantity)
        VALUES (?, ?, ?)
      `).run(itemId, type, quantity);

      return db.prepare(`
        SELECT t.*, i.name AS item_name
        FROM transactions t
        JOIN items i ON t.item_id = i.id
        WHERE t.id = ?
      `).get(insertResult.lastInsertRowid);
    });

    const newTransaction = executeTransaction();
    return res.status(201).json(newTransaction);
  } catch (err) {
    return res.status(500).json({ error: 'Failed to record transaction' });
  }
});

// GET /api/transactions - list transactions (optionally filtered by itemId, newest first)
router.get('/api/transactions', (req, res) => {
  try {
    const itemId = req.query.itemId || req.query.item_id;
    let transactions;

    if (itemId) {
      transactions = db.prepare(`
        SELECT t.*, i.name AS item_name
        FROM transactions t
        JOIN items i ON t.item_id = i.id
        WHERE t.item_id = ?
        ORDER BY t.id DESC
      `).all(itemId);
    } else {
      transactions = db.prepare(`
        SELECT t.*, i.name AS item_name
        FROM transactions t
        JOIN items i ON t.item_id = i.id
        ORDER BY t.id DESC
      `).all();
    }

    return res.json(transactions);
  } catch (err) {
    return res.status(500).json({ error: 'Failed to retrieve transactions' });
  }
});

module.exports = router;
