const mongoose = require('mongoose');

const ReportSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String, required: true },
  category: { type: String, required: true },
  status: { type: String, default: 'Reported' }, // Reported, Verified, In Progress, Resolved
  priority: { type: String, default: 'Normal' },
  upvotes: { type: Number, default: 0 },
  commentCount: { type: Number, default: 0 },
  imageUrl: { type: String, default: "" },
  location: {
    lat: { type: Number },
    lng: { type: Number },
    address: { type: String }
  },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  statusHistory: { type: Object, default: {} },
  slaDays: { type: Number, default: 10 },
  expectedResolutionDate: { type: Date }
}, {
  timestamps: true
});

module.exports = mongoose.model('Report', ReportSchema);
