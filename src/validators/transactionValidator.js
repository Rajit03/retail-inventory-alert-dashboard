function validateTransaction(data = {}) {
  const errors = [];
  const itemId = data.item_id !== undefined ? data.item_id : data.itemId;
  const { type, quantity } = data;

  if (
    itemId === undefined ||
    itemId === null ||
    itemId === '' ||
    isNaN(Number(itemId)) ||
    !Number.isInteger(Number(itemId)) ||
    Number(itemId) <= 0
  ) {
    errors.push('Item ID is required and must be a valid item.');
  }

  const validTypes = ['IN', 'OUT', 'ADJUST'];
  if (!type || typeof type !== 'string' || !validTypes.includes(type.toUpperCase())) {
    errors.push("Transaction type must be 'IN', 'OUT', or 'ADJUST'.");
  }

  const numQty = Number(quantity);
  if (
    quantity === undefined ||
    quantity === null ||
    quantity === '' ||
    isNaN(numQty) ||
    !Number.isInteger(numQty)
  ) {
    errors.push('Quantity must be a valid integer.');
  } else {
    const normType = type ? type.toUpperCase() : '';
    if ((normType === 'IN' || normType === 'OUT') && numQty <= 0) {
      errors.push(`Quantity must be greater than 0 for ${normType} transactions.`);
    } else if (normType === 'ADJUST' && numQty < 0) {
      errors.push('Quantity must be greater than or equal to 0 for ADJUST transactions.');
    }
  }

  return errors;
}

module.exports = validateTransaction;
