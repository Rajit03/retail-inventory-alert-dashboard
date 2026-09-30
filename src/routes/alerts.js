const express = require('express');
const router = express.Router();
const db = require('../db/database');

function computeAlerts(items) {
  const today = new Date().toISOString().split('T')[0];
  const alerts = [];

  for (const item of items) {
    const quantity = Number(item.quantity);
    const threshold = Number(item.reorder_threshold);

    if (quantity === 0) {
      alerts.push({
        item_id: item.id,
        item_name: item.name,
        type: 'OUT_OF_STOCK',
        message: `${item.name} is completely out of stock.`
      });
    } else if (quantity <= threshold) {
      alerts.push({
        item_id: item.id,
        item_name: item.name,
        type: 'LOW_STOCK',
        message: `${item.name} has low stock (${quantity} remaining, threshold: ${threshold}).`
      });
    }

    if (item.order_status === 'ORDERED' && item.expected_date && item.expected_date < today) {
      alerts.push({
        item_id: item.id,
        item_name: item.name,
        type: 'DELAYED_ORDER',
        message: `Order for ${item.name} is delayed. Expected delivery was ${item.expected_date}.`
      });
    }
  }

  return alerts;
}

// GET /api/alerts - computed alerts list
router.get('/api/alerts', (req, res) => {
  try {
    const items = db.prepare('SELECT * FROM items ORDER BY id ASC').all();
    const alerts = computeAlerts(items);
    res.json(alerts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to retrieve alerts' });
  }
});

// GET /alerts - alerts page
router.get('/alerts', (req, res) => {
  try {
    const items = db.prepare('SELECT * FROM items ORDER BY id ASC').all();
    const alerts = computeAlerts(items);
    res.render('alerts/index', { alerts });
  } catch (err) {
    res.status(500).send('Error loading alerts page');
  }
});

module.exports = router;
