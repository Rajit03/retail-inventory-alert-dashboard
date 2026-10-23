const db = require('../db/database');
const {
  migrateUsers,
  seedUsers,
  migrateAndSeedUsers,
  getUserByUsername
} = require('./db');
const {
  BCRYPT_COST,
  hashPassword,
  hashPasswordSync,
  comparePassword,
  comparePasswordSync
} = require('./hash');
const { PERMISSIONS, can } = require('./permissions');
const {
  securityHeaders,
  createSessionMiddleware,
  ensureCsrfToken,
  verifyCsrf,
  sanitizeNext,
  getLandingPage,
  requireLogin,
  requirePermission
} = require('./middleware');
const { loginLimiter, resetLoginLimiter, limiterStore } = require('./limiter');
const authRouter = require('./routes');

// Run initial migration and seeding for current database
migrateAndSeedUsers(db);

module.exports = {
  migrateUsers,
  seedUsers,
  migrateAndSeedUsers,
  getUserByUsername,
  BCRYPT_COST,
  hashPassword,
  hashPasswordSync,
  comparePassword,
  comparePasswordSync,
  PERMISSIONS,
  can,
  securityHeaders,
  createSessionMiddleware,
  ensureCsrfToken,
  verifyCsrf,
  sanitizeNext,
  getLandingPage,
  requireLogin,
  requirePermission,
  loginLimiter,
  resetLoginLimiter,
  limiterStore,
  authRouter
};
