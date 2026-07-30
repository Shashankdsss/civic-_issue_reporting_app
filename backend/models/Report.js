const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String, required: true },
  location: { type: String, required: true },
  status: {
    type: String,
    enum: ['Reported', 'Verified', 'In Progress', 'Resolved'],
    default: 'Reported'
  },
  severity: { type: String, enum: ['Low', 'Medium', 'High'], default: 'Medium' },
  imageUrl: { type: String, default: '' },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }
}, {
  timestamps: true
});

module.exports = mongoose.model('Report', reportSchema);
