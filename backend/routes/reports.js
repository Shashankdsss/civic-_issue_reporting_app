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
    const report = await Report.findByIdAndUpdate(
      req.params.id,
      { $set: { status } },
      { new: true }
    );
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

module.exports = router;
