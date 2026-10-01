const { describe, it } = require('node:test');
const assert = require('node:assert');
const getStockStatus = require('../../src/utils/stockStatus');

describe('Stock Status Calculation', () => {
  it('should return IN_STOCK when quantity is strictly greater than threshold', () => {
    assert.strictEqual(getStockStatus(15, 10), 'IN_STOCK');
    assert.strictEqual(getStockStatus({ quantity: 20, reorder_threshold: 10 }), 'IN_STOCK');
  });

  it('should return LOW_STOCK when quantity is equal to threshold', () => {
    assert.strictEqual(getStockStatus(10, 10), 'LOW_STOCK');
    assert.strictEqual(getStockStatus({ quantity: 10, reorder_threshold: 10 }), 'LOW_STOCK');
  });

  it('should return LOW_STOCK when quantity is less than threshold but greater than 0', () => {
    assert.strictEqual(getStockStatus(3, 10), 'LOW_STOCK');
    assert.strictEqual(getStockStatus({ quantity: 1, reorder_threshold: 5 }), 'LOW_STOCK');
  });

  it('should return OUT_OF_STOCK when quantity is 0', () => {
    assert.strictEqual(getStockStatus(0, 10), 'OUT_OF_STOCK');
    assert.strictEqual(getStockStatus({ quantity: 0, reorder_threshold: 5 }), 'OUT_OF_STOCK');
  });
});
