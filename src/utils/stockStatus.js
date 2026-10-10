function getStockStatus(quantityOrItem, reorderThreshold) {
  let quantity, threshold;
  if (typeof quantityOrItem === 'object' && quantityOrItem !== null) {
    quantity = Number(quantityOrItem.quantity);
    threshold = Number(quantityOrItem.reorder_threshold);
  } else {
    quantity = Number(quantityOrItem);
    threshold = Number(reorderThreshold);
  }

  if (isNaN(quantity) || quantity === 0) {
    return 'OUT_OF_STOCK';
  }
  if (quantity <= threshold) {
    return 'LOW_STOCK';
  }
  return 'IN_STOCK';
}

module.exports = getStockStatus;
module.exports.getStockStatus = getStockStatus;
