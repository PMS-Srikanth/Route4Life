const Hospital = require('../models/Hospital');

// GET /api/hospitals?lat=&lng=&radius=
const getHospitals = async (req, res) => {
  const { lat, lng, radius } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({ message: 'lat and lng are required' });
  }

  const radiusMeters = parseFloat(radius) || 10000; // default 10km

  try {
    // Use MongoDB $nearSphere geospatial query
    const hospitals = await Hospital.find({
      location: {
        $nearSphere: {
          $geometry: {
            type: 'Point',
            coordinates: [parseFloat(lng), parseFloat(lat)],
          },
          $maxDistance: radiusMeters,
        },
      },
    });

    res.json(hospitals);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// GET /api/hospitals/:id
const getHospitalById = async (req, res) => {
  try {
    const hospital = await Hospital.findById(req.params.id);
    if (!hospital) return res.status(404).json({ message: 'Hospital not found' });
    res.json(hospital);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// POST /api/hospitals  (admin use)
const createHospital = async (req, res) => {
  const { name, address, lat, lng, icuAvailable, doctorAvailable, icuBeds, phone } = req.body;
  try {
    const hospital = await Hospital.create({
      name,
      address,
      lat,
      lng,
      location: { type: 'Point', coordinates: [lng, lat] },
      icuAvailable,
      doctorAvailable,
      icuBeds,
      phone,
    });
    res.status(201).json(hospital);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// PATCH /api/hospitals/:id  (update availability)
const updateHospital = async (req, res) => {
  try {
    const hospital = await Hospital.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    if (!hospital) return res.status(404).json({ message: 'Hospital not found' });
    res.json(hospital);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

module.exports = { getHospitals, getHospitalById, createHospital, updateHospital };
