const fs = require('fs');

// Global Crash Logger for CloudPanel Debugging
process.on('uncaughtException', (err) => {
  fs.writeFileSync('error_log.txt', "UNCAUGHT FATAL ERROR: \n" + err.stack);
  console.error(err);
  process.exit(1);
});
process.on('unhandledRejection', (err) => {
  fs.writeFileSync('error_log.txt', "UNHANDLED PROMISE REJECTION: \n" + (err && err.stack ? err.stack : err));
  console.error(err);
  process.exit(1);
});

require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const reportRoutes = require('./routes/reports');
const communityRoutes = require('./routes/community');

const app = express();

// Middleware
app.use(cors());
app.use(express.json()); // Parse JSON bodies

app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/community', communityRoutes);

// Basic health check route
app.get('/api/health', (req, res) => {
  res.json({
    status: 'running',
    mongoConnection: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

app.get('/', (req, res) => {
  res.send('CivicConnect API is running.');
});

// Configure MongoDB connection
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('✅ Connected to MongoDB Atlas'))
  .catch(err => console.error('❌ MongoDB Connection Error:', err));

// Start server
const PORT = process.env.PORT || 3016;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
