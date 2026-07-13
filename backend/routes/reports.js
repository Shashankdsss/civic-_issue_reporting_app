const express = require('express');
const Report = require('../models/Report');

const router = express.Router();

// Get all reports
router.get('/', async (req, res) => {
  try {
    const reports = await Report.find().sort({ createdAt: -1 });
    // Map _id to id for backwards compatibility with flutter app
    const mappedReports = reports.map(r => {
      const doc = r.toObject();
      doc.id = doc._id.toString();
      return doc;
    });
    res.json(mappedReports);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// Insert new report
router.post('/', async (req, res) => {
  try {
    const newReport = new Report(req.body);
    const report = await newReport.save();
    res.status(201).json({ id: report._id, message: "Report added successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// Delete a report
router.delete('/:id', async (req, res) => {
  try {
    await Report.findByIdAndDelete(req.params.id);
    res.json({ message: "Report deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// Update Report Status
router.patch('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    await Report.findByIdAndUpdate(req.params.id, {
      $set: { status },
      $set: { [`statusHistory.${status}`]: new Date() }
    });
    res.json({ message: "Status updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  }
});

// Upvote a report
router.post('/:id/upvote', async (req, res) => {
  try {
    const report = await Report.findById(req.params.id);
    if(report) {
      report.upvotes += 1;
      await report.save();
    }
    res.json({ message: "Upvoted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error" });
  } 
});

module.exports = router;
