function validateItem(data = {}) {
  const errors = [];
  const { name, category, price, quantity, reorder_threshold } = data;

  if (!name || typeof name !== 'string' || name.trim() === '') {
    errors.push('Name is required and cannot be empty.');
  } else if (name.trim().length > 100) {
    errors.push('Name cannot exceed 100 characters.');
  }

  if (!category || typeof category !== 'string' || category.trim() === '') {
    errors.push('Category is required and cannot be empty.');
  } else if (category.trim().length > 50) {
    errors.push('Category cannot exceed 50 characters.');
  }

  if (
    price === undefined ||
    price === null ||
    price === '' ||
    isNaN(Number(price)) ||
    Number(price) < 0
  ) {
    errors.push('Price must be a number greater than or equal to 0.');
  }

  if (
    quantity === undefined ||
    quantity === null ||
    quantity === '' ||
    isNaN(Number(quantity)) ||
    !Number.isInteger(Number(quantity)) ||
    Number(quantity) < 0
  ) {
    errors.push('Quantity must be an integer greater than or equal to 0.');
  }

  if (
    reorder_threshold === undefined ||
    reorder_threshold === null ||
    reorder_threshold === '' ||
    isNaN(Number(reorder_threshold)) ||
    !Number.isInteger(Number(reorder_threshold)) ||
    Number(reorder_threshold) < 0
  ) {
    errors.push('Reorder threshold must be an integer greater than or equal to 0.');
  }

  return errors;
}

validateItem.validateItem = validateItem;
module.exports = validateItem;
