const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  category: { type: String, required: true },
  description: { type: String, required: true },
  latitude: { type: Number, required: true },
  longitude: { type: Number, required: true },
  status: {
    type: String,
    enum: ['Reported', 'Pending', 'Verified', 'Assigned', 'In Progress', 'Resolved'],
    default: 'Reported'
  },
  priority: { type: String, enum: ['Low', 'Medium', 'High'], default: 'Medium' },
  imagePath: { type: String, default: '' },
  mediaType: { type: String, default: 'image' },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: { type: String, default: 'Citizen' },
  assignedDepartment: { type: String, default: '' },
  targetCompletionDate: { type: Date, default: null },
  adminRemarks: { type: String, default: '' },
  upvotes: { type: Number, default: 0 }
}, {
  timestamps: true
});

module.exports = mongoose.model('Report', reportSchema);
