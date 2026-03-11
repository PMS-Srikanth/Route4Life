const Case = require('../models/Case');

// POST /api/cases
const createCase = async (req, res) => {
  const { caseId, patientName, emergencyType, lat, lng, dispatchedBy, driverId } = req.body;

  try {
    const existing = await Case.findOne({ caseId });
    if (existing) return res.json(existing);

    const newCase = await Case.create({
      caseId,
      patientName,
      emergencyType,
      lat,
      lng,
      dispatchedBy,
      driver: driverId,
    });

    res.status(201).json(newCase);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// GET /api/cases/:caseId
const getCaseById = async (req, res) => {
  try {
    const c = await Case.findOne({ caseId: req.params.caseId })
      .populate('assignedHospital', 'name address lat lng phone');
    if (!c) return res.status(404).json({ message: 'Case not found' });
    res.json(c);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// PATCH /api/cases/:caseId/lock  — lock hospital after pickup
const lockHospital = async (req, res) => {
  const { hospitalId } = req.body;
  try {
    const c = await Case.findOneAndUpdate(
      { caseId: req.params.caseId },
      { assignedHospital: hospitalId, hospitalLocked: true, status: 'patientOnBoard' },
      { new: true }
    );
    if (!c) return res.status(404).json({ message: 'Case not found' });
    res.json(c);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// PATCH /api/cases/:caseId/complete
const completeCase = async (req, res) => {
  try {
    const c = await Case.findOneAndUpdate(
      { caseId: req.params.caseId },
      { status: 'complete' },
      { new: true }
    );
    if (!c) return res.status(404).json({ message: 'Case not found' });
    res.json(c);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

module.exports = { createCase, getCaseById, lockHospital, completeCase };
