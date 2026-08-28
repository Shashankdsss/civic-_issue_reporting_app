const express = require('express');
const Report = require('../models/Report');
const jwt = require('jsonwebtoken');

const router = express.Router();

// Middleware to protect routes
const auth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.status(401).json({ error: "No token provided" });
  
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded.user;
    next();
  } catch (e) {
    res.status(401).json({ error: "Token is not valid" });
  }
};

// Create a new report
router.post('/', auth, async (req, res) => {
  try {
    const { category, description, latitude, longitude, priority, imagePath, department, mediaType, userName } = req.body;
    
    // Duplicate check (~50m radius)
    const latDelta = 0.00045;
    const lonDelta = 0.00045;
    
    const duplicate = await Report.findOne({
      category: category,
      latitude: { $gte: latitude - latDelta, $lte: latitude + latDelta },
      longitude: { $gte: longitude - lonDelta, $lte: longitude + lonDelta },
      status: { $ne: 'Resolved' }
    });
    
    if (duplicate) {
      return res.status(400).json({ error: "Duplicate issue detected. This civic issue has already been reported nearby." });
    }

    const newReport = new Report({
      category,
      description,
      latitude,
      longitude,
      priority,
      imagePath,
      mediaType,
      assignedDepartment: department,
      userName,
      userId: req.user.id
    });
    
    const report = await newReport.save();
    res.json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Get all reports
router.get('/', async (req, res) => {
  try {
    const reports = await Report.find().sort({ createdAt: -1 });
    res.json(reports);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Get reports by User ID
router.get('/my-reports', auth, async (req, res) => {
  try {
    const reports = await Report.find({ userId: req.user.id }).sort({ createdAt: -1 });
    res.json(reports);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Update Report Status (usually for admin, but leaving unprotected for demo purpose)
router.patch('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const report = await Report.findById(req.params.id);
    if (!report) return res.status(404).json({ error: "Report not found" });

    // Check if status is transitioning to Resolved
    if (status === 'Resolved' && report.status !== 'Resolved') {
      const User = require('../models/User');
      const Notification = require('../models/Notification');
      
      // Increment Civic Wallet points by 10
      await User.findByIdAndUpdate(report.userId, { $inc: { civicPoints: 10 } });
      
      // Send a Notification to the reporter
      await new Notification({
        userId: report.userId,
        title: "Issue Resolved",
        message: `Your report for ${report.category} has been safely resolved! You earned 10 Civic Points in your wallet.`,
        reportId: report._id
      }).save();
    }

    report.status = status;
    await report.save();

    res.json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Update Upvotes
router.post('/:id/upvote', auth, async (req, res) => {
  try {
    const { upvotes } = req.body;
    const report = await Report.findByIdAndUpdate(
      req.params.id,
      { $set: { upvotes: Math.max(0, upvotes) } },
      { new: true }
    );
    res.json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Get a single report by ID
router.get('/:id', async (req, res) => {
  try {
    const report = await Report.findById(req.params.id);
    if (!report) return res.status(404).json({ error: "Report not found" });
    res.json(report);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Delete a single report
router.delete('/:id', auth, async (req, res) => {
  try {
    const report = await Report.findByIdAndDelete(req.params.id);
    if (!report) return res.status(404).json({ error: "Report not found" });
    res.json({ message: "Report deleted successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// Delete all reports
router.delete('/', auth, async (req, res) => {
  try {
    await Report.deleteMany({});
    res.json({ message: "All reports deleted successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

module.exports = router;
