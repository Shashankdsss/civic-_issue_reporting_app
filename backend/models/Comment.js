const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  reportId: { type: String, required: true },
  userId: { type: String, required: true },
  userName: { type: String, required: true },
  message: { type: String, required: true }
}, {
  timestamps: true
});

module.exports = mongoose.model('Comment', commentSchema);
