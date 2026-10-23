const PERMISSIONS = {
  manager: [
    'items:write',
    'transactions:write',
    'orders:update',
    'items:read',
    'transactions:read',
    'alerts:read'
  ],
  staff: [
    'items:write',
    'transactions:write',
    'orders:update',
    'items:read',
    'transactions:read',
    'alerts:read'
  ],
  purchasing: [
    'orders:update',
    'items:read',
    'transactions:read',
    'alerts:read'
  ]
};

function can(role, action) {
  if (!role || typeof role !== 'string' || !action || typeof action !== 'string') {
    return false;
  }
  if (role === 'manager') {
    return true;
  }
  const rolePermissions = PERMISSIONS[role];
  if (!rolePermissions) {
    return false;
  }
  return rolePermissions.includes(action);
}

module.exports = {
  PERMISSIONS,
  can
};
