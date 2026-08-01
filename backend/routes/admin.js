const express = require('express');
const router = express.Router();
const Report = require('../models/Report');
const User = require('../models/User');
const authAdmin = require('../middleware/authAdmin');

// Get all reports across the system (Admin only)
router.get('/reports', authAdmin, async (req, res) => {
  try {
    // Populate the userId to get reporter details
    const reports = await Report.find()
      .populate('userId', 'firstName lastName email phone region')
      .sort({ createdAt: -1 });
    
    res.json(reports);
  } catch (error) {
    console.error("Error fetching reports for admin:", error);
    res.status(500).json({ error: "Server error fetching reports." });
  }
});

const Notification = require('../models/Notification');

// Update a report's status, assignment, remarks, date (Admin only)
router.put('/reports/:id', authAdmin, async (req, res) => {
  try {
    const { status, assignedDepartment, targetCompletionDate, slaDays, expectedStages, adminRemarks } = req.body;
    
    const report = await Report.findById(req.params.id);
    if (!report) {
      return res.status(404).json({ error: "Report not found" });
    }

    // Check if SLA was just allocated
    const isNewAllocation = (slaDays !== undefined && expectedStages !== undefined && !report.slaDays);

    // Only update fields that were provided in the request
    if (status) report.status = status;
    if (assignedDepartment !== undefined) report.assignedDepartment = assignedDepartment;
    if (targetCompletionDate !== undefined) report.targetCompletionDate = targetCompletionDate;
    if (slaDays !== undefined) report.slaDays = slaDays;
    if (expectedStages !== undefined) report.expectedStages = expectedStages;
    if (adminRemarks !== undefined) report.adminRemarks = adminRemarks;

    await report.save();
    
    // Create a notification for the citizen if SLA was allocated
    if (isNewAllocation) {
      await Notification.create({
        userId: report.userId,
        title: "SLA Timeline Allocated",
        message: `An admin has reviewed your ${report.category} report and allocated a ${slaDays}-day timeline. Expected resolution is on ${new Date(targetCompletionDate).toLocaleDateString()}.`,
        reportId: report._id
      });
    }

    // Return updated report populated with user data
    const updatedReport = await Report.findById(req.params.id)
      .populate('userId', 'firstName lastName email phone');

      
    res.json(updatedReport);
  } catch (error) {
    console.error("Error updating report via admin:", error);
    res.status(500).json({ error: "Server error updating report." });
  }
});

module.exports = router;
