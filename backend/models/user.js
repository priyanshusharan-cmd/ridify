const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  name: String, age: String, email: { type: String, unique: true }, password: String
});

module.exports = mongoose.model('User', UserSchema);
