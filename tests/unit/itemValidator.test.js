const { describe, it } = require('node:test');
const assert = require('node:assert');
const validateItem = require('../../src/validators/itemValidator');

describe('Item Input Validator', () => {
  const validItem = {
    name: 'Wireless Keyboard',
    category: 'Electronics',
    price: 49.99,
    quantity: 10,
    reorder_threshold: 5
  };

  it('should accept valid item data with no errors', () => {
    const errors = validateItem(validItem);
    assert.strictEqual(errors.length, 0);
  });

  it('should reject missing or empty name', () => {
    const errorsEmpty = validateItem({ ...validItem, name: '' });
    assert.ok(errorsEmpty.length > 0);
    assert.ok(errorsEmpty.some(e => e.toLowerCase().includes('name is required')));

    const errorsWhitespace = validateItem({ ...validItem, name: '   ' });
    assert.ok(errorsWhitespace.length > 0);
  });

  it('should reject negative price', () => {
    const errors = validateItem({ ...validItem, price: -5.0 });
    assert.ok(errors.length > 0);
    assert.ok(errors.some(e => e.toLowerCase().includes('price')));
  });

  it('should reject non-integer quantity', () => {
    const errors = validateItem({ ...validItem, quantity: 4.5 });
    assert.ok(errors.length > 0);
    assert.ok(errors.some(e => e.toLowerCase().includes('quantity')));
  });

  it('should reject name over 100 characters', () => {
    const longName = 'A'.repeat(101);
    const errors = validateItem({ ...validItem, name: longName });
    assert.ok(errors.length > 0);
    assert.ok(errors.some(e => e.includes('100 characters')));
  });

  it('should reject category over 50 characters', () => {
    const longCat = 'B'.repeat(51);
    const errors = validateItem({ ...validItem, category: longCat });
    assert.ok(errors.length > 0);
    assert.ok(errors.some(e => e.includes('50 characters')));
  });
});
