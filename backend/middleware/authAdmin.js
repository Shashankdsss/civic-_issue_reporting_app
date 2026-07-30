const jwt = require('jsonwebtoken');
const User = require('../models/User');

module.exports = async function(req, res, next) {
  // Get token from header
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'No token, authorization denied' });
  }

  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if jwt payload has admin role (bypasses DB restriction for testing)
    if (decoded.user.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied: Requires Admin privileges' });
    }

    req.user = decoded.user;
    req.adminData = {}; // Skipped db lookup wrapper
    next();
  } catch (err) {
    res.status(401).json({ error: 'Token is not valid' });
  }
};
