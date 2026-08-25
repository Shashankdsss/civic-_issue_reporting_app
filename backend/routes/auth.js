const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const router = express.Router();

// Register a new user
router.post('/register', async (req, res) => {
  try {
    const { firstName, lastName, email, phone, aadhaar, gender, password, otherDetails, region } = req.body;
    
    // Check if user already exists
    let user = await User.findOne({ email });
    if (user) {
      return res.status(400).json({ error: "An account with this Email already exists." });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create user
    user = new User({
      firstName, lastName, email, phone, aadhaar, gender, password: hashedPassword, otherDetails, region
    });

    await user.save();
    res.status(201).json({ message: "Registration successful" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error during registration." });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password, role, passkey } = req.body;
    const requestedRole = role || 'citizen';

    // SUPER ADMIN ACCOUNTS
    if (email === 'shashank@gmail.com') {
      if (password !== '123123123' || passkey !== 'ysofunny') {
        return res.status(403).json({ error: "Access Denied. Invalid credentials or passkey." });
      }
      
      const payload = {
        user: {
          id: "000000000000000000000000",
          role: requestedRole
        }
      };
      
      return jwt.sign(
        payload,
        process.env.JWT_SECRET,
        { expiresIn: '7d' },
        (err, token) => {
          if (err) throw err;
          res.json({
            token,
            userId: "000000000000000000000000",
            role: requestedRole,
            department: ""
          });
        }
      );
    }

    // HARDCODED CITIZEN ACCOUNT
    if (email === 'kulalshashank272@gmail.com') {
      if (password !== 's123@#') {
        return res.status(403).json({ error: "Access Denied. Invalid credentials." });
      }
      
      const payload = {
        user: {
          id: "111111111111111111111111",
          role: 'citizen'
        }
      };
      
      return jwt.sign(
        payload,
        process.env.JWT_SECRET,
        { expiresIn: '7d' },
        (err, token) => {
          if (err) throw err;
          res.json({
            token,
            userId: "111111111111111111111111",
            role: 'citizen',
            department: ""
          });
        }
      );
    }
    // Check email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ error: "Invalid Email or Password." });
    }

    // Check pass
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: "Invalid Email or Password." });
    }

    // Create JWT
    const payload = {
      user: {
        id: user.id,
        role: requestedRole
      }
    };

    // Record login time without triggering full document schema validation
    await User.updateOne({ _id: user._id }, { $set: { lastLogin: new Date() } });

    jwt.sign(
      payload,
      process.env.JWT_SECRET,
      { expiresIn: '7d' },
      (err, token) => {
        if (err) throw err;
        res.json({ 
          token, 
          userId: user.id,
          role: requestedRole,
          department: user.department 
        });
      }
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error during login." });
  }
});

// Get current User profile info
router.get('/me', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'No token provided' });
    const token = authHeader.split(' ')[1];
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if it's the forged super admin
    if (decoded.user.id === '000000000000000000000000') {
      return res.json({ 
        _id: '000000000000000000000000', 
        firstName: 'System', 
        lastName: 'Admin', 
        email: 'shashank@gmail.com', 
        role: 'admin' 
      });
    }

    // Check if it's the forged citizen
    if (decoded.user.id === '111111111111111111111111') {
      return res.json({ 
        _id: '111111111111111111111111', 
        firstName: 'Shashank', 
        lastName: 'Kulal', 
        email: 'kulalshashank272@gmail.com', 
        role: 'citizen' 
      });
    }

    const user = await User.findById(decoded.user.id).select('-password');
    res.json(user);
    
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error fetching user." });
  }
});

// Update Bank Details
router.put('/bank', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'No token provided' });
    const token = authHeader.split(' ')[1];
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.user.role === 'admin') return res.status(403).json({ error: 'Admin cannot use this route' });

    const { bankAccount, ifscCode } = req.body;
    
    const user = await User.findByIdAndUpdate(
      decoded.user.id, 
      { $set: { bankAccount, ifscCode } }, 
      { new: true }
    ).select('-password');

    res.json(user);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error updating bank details." });
  }
});

// Update Profile Details
router.put('/profile', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'No token provided' });
    const token = authHeader.split(' ')[1];
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.user.role === 'admin') return res.status(403).json({ error: 'Admin cannot use this route' });

    const { name, phone } = req.body;
    
    let firstName = name;
    let lastName = "";
    if (name && name.includes(' ')) {
      const parts = name.split(' ');
      firstName = parts[0];
      lastName = parts.slice(1).join(' ');
    }
    
    const user = await User.findByIdAndUpdate(
      decoded.user.id, 
      { $set: { firstName, lastName, phone } }, 
      { new: true }
    ).select('-password');

    res.json(user);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Server error updating profile details." });
  }
});

module.exports = router;
