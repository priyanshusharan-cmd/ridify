const mongoose = require('mongoose');

const MAX_FIELD_LENGTH = parseInt(process.env.MAX_FIELD_LENGTH) || 500;

/**
 * Validate email format: must have local part, @, and a TLD (e.g. .com)
 */
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$/.test(String(email).trim());
}

/**
 * Validate that a string is a valid MongoDB ObjectId.
 */
function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

module.exports = {
  MAX_FIELD_LENGTH,
  isValidEmail,
  isValidObjectId,
};
