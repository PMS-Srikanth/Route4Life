const jwt = require('jsonwebtoken');
const Driver = require('../models/Driver');

// POST /api/auth/login
const login = async (req, res) => {
  const { phone, password } = req.body;

  try {
    const driver = await Driver.findOne({ phone });
    if (!driver) {
      return res.status(401).json({ message: 'Invalid phone or password' });
    }

    const isMatch = await driver.matchPassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Invalid phone or password' });
    }

    const token = jwt.sign(
      { id: driver._id },
      process.env.JWT_SECRET,
      { expiresIn: '12h' }
    );

    res.json({
      _id: driver._id,
      name: driver.name,
      phone: driver.phone,
      vehicleNumber: driver.vehicleNumber,
      token,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// POST /api/auth/register  (for seeding / admin use)
const register = async (req, res) => {
  const { name, phone, password, vehicleNumber } = req.body;

  try {
    const existing = await Driver.findOne({ phone });
    if (existing) {
      return res.status(400).json({ message: 'Driver already exists' });
    }
    const driver = await Driver.create({ name, phone, password, vehicleNumber });
    res.status(201).json({ message: 'Driver registered', id: driver._id });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

module.exports = { login, register };
