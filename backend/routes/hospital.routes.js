const express = require('express');
const router = express.Router();
const {
  getHospitals,
  getHospitalById,
  createHospital,
  updateHospital,
} = require('../controllers/hospital.controller');

router.get('/', getHospitals);           // GET /api/hospitals?lat=&lng=&radius=
router.get('/:id', getHospitalById);     // GET /api/hospitals/:id
router.post('/', createHospital);        // POST /api/hospitals
router.patch('/:id', updateHospital);    // PATCH /api/hospitals/:id

module.exports = router;
