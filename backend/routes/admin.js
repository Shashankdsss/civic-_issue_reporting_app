const express = require('express');
const router = express.Router();
const User = require('../models/User');

// Admin panel route
router.get('/', async (req, res) => {
  try {
    const users = await User.find().sort({ lastLogin: -1 });

    let html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CivicConnect Admin Panel</title>
        <style>
          body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f4f7fa;
            margin: 0;
            padding: 20px;
            color: #333;
          }
          h1 {
            color: #2c3e50;
            text-align: center;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            background-color: #fff;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            margin-top: 20px;
          }
          th, td {
            text-align: left;
            padding: 12px 15px;
            border-bottom: 1px solid #e0e0e0;
          }
          th {
            background-color: #34495e;
            color: white;
          }
          tr:hover {
            background-color: #f5f5f5;
          }
          .empty-state {
            text-align: center;
            padding: 20px;
            color: #777;
          }
        </style>
      </head>
      <body>
        <h1>CivicConnect Users Admin Panel</h1>
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Phone</th>
              <th>Region</th>
              <th>Last Login</th>
            </tr>
          </thead>
          <tbody>
    `;

    if (users.length === 0) {
        html += `<tr><td colspan="5" class="empty-state">No users found in database.</td></tr>`;
    } else {
        users.forEach(user => {
            const loginTime = user.lastLogin 
                ? new Date(user.lastLogin).toLocaleString() 
                : "Never Logged In";
            
            html += `
              <tr>
                <td>${user.firstName} ${user.lastName}</td>
                <td>${user.email}</td>
                <td>${user.phone}</td>
                <td>${user.region}</td>
                <td>${loginTime}</td>
              </tr>
            `;
        });
    }

    html += `
          </tbody>
        </table>
      </body>
      </html>
    `;

    res.send(html);
  } catch (error) {
    console.error("Error loading admin panel:", error);
    res.status(500).send("Internal Server Error loading Admin Panel.");
  }
});

module.exports = router;
