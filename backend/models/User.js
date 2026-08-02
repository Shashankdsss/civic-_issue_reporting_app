const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  phone: { type: String, required: true },
  aadhaar: { type: String, required: true },
  gender: { type: String, required: true },
  password: { type: String, required: true },
  otherDetails: { type: String, default: '' },
  region: { type: String, default: 'Unknown' },
  lastLogin: { type: Date, default: null },
  following: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  role: { type: String, enum: ['citizen', 'admin'], default: 'citizen' },
  department: { type: String, default: '' },
  civicPoints: { type: Number, default: 0 },
  bankAccount: { type: String, default: '' },
  ifscCode: { type: String, default: '' }
}, {
  timestamps: true
});

module.exports = mongoose.model('User', userSchema);
