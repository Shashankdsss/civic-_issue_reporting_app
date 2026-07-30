const express = require('express');
const User = require('../models/User');
const Report = require('../models/Report');
const Comment = require('../models/Comment');
const jwt = require('jsonwebtoken');

const router = express.Router();

// Auth middleware
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

// ── GET ALL USERS (for Neighbors tab) ─────────────────────────────────
router.get('/users', async (req, res) => {
  try {
    const users = await User.find().select('firstName lastName region');
    const mapped = users.map(u => ({
      uid: u._id.toString(),
      name: `${u.firstName} ${u.lastName}`,
      region: u.region || 'Unknown'
    }));
    res.json(mapped);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// ── FOLLOW A USER ─────────────────────────────────────────────────────
router.post('/follow', auth, async (req, res) => {
  try {
    const { targetUid } = req.body;
    await User.findByIdAndUpdate(req.user.id, { $addToSet: { following: targetUid } });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// ── UNFOLLOW A USER ───────────────────────────────────────────────────
router.post('/unfollow', auth, async (req, res) => {
  try {
    const { targetUid } = req.body;
    await User.findByIdAndUpdate(req.user.id, { $pull: { following: targetUid } });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// ── GET FOLLOWING LIST ────────────────────────────────────────────────
router.get('/following', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('following');
    res.json(user?.following?.map(id => id.toString()) || []);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// ── ADD COMMENT ───────────────────────────────────────────────────────
router.post('/comments', auth, async (req, res) => {
  try {
    const { reportId, userName, message } = req.body;
    const comment = new Comment({
      reportId,
      userId: req.user.id,
      userName,
      message
    });
    await comment.save();
    res.status(201).json(comment);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// ── GET COMMENTS FOR A REPORT ─────────────────────────────────────────
router.get('/comments/:reportId', async (req, res) => {
  try {
    const comments = await Comment.find({ reportId: req.params.reportId }).sort({ createdAt: -1 });
    res.json(comments);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

// ── LEADERBOARD ───────────────────────────────────────────────────────
router.get('/leaderboard', async (req, res) => {
  try {
    const users = await User.find().select('firstName lastName region');
    const reports = await Report.find();
    const comments = await Comment.find();

    const scores = users.map(u => {
      const uid = u._id.toString();
      const userReports = reports.filter(r => r.userId?.toString() === uid);
      const userComments = comments.filter(c => c.userId === uid);
      const resolved = userReports.filter(r => r.status === 'Resolved');

      const score = (userReports.length * 10) + (resolved.length * 5) + (userComments.length * 1);

      return {
        uid,
        name: `${u.firstName} ${u.lastName}`,
        region: u.region || 'Unknown',
        reports: userReports.length,
        resolved: resolved.length,
        comments: userComments.length,
        score
      };
    });

    scores.sort((a, b) => b.score - a.score);
    res.json(scores);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server Error" });
  }
});

module.exports = router;
