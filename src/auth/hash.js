const bcrypt = require('bcryptjs');

const BCRYPT_COST = 12;

function hashPassword(password) {
  return bcrypt.hash(password, BCRYPT_COST);
}

function hashPasswordSync(password) {
  return bcrypt.hashSync(password, BCRYPT_COST);
}

function comparePassword(password, hash) {
  return bcrypt.compare(password, hash);
}

function comparePasswordSync(password, hash) {
  return bcrypt.compareSync(password, hash);
}

module.exports = {
  BCRYPT_COST,
  hashPassword,
  hashPasswordSync,
  comparePassword,
  comparePasswordSync
};
