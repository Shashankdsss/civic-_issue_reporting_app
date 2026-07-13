const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  phone: { type: String, required: true },
  aadhaar: { type: String, required: true },
  gender: { type: String, required: true },
  otherDetails: { type: String, default: "" },
  region: { type: String, default: "Unknown" }
}, {
  timestamps: true // adds createdAt, updatedAt
});

module.exports = mongoose.model('User', UserSchema);
