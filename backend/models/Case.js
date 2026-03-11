const mongoose = require('mongoose');

const caseSchema = new mongoose.Schema({
  caseId: { type: String, required: true, unique: true },
  patientName: { type: String, default: 'Unknown' },
  emergencyType: { type: String, default: 'Critical' },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  dispatchedBy: { type: String, default: '108 Control' },
  driver: { type: mongoose.Schema.Types.ObjectId, ref: 'Driver' },
  assignedHospital: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', default: null },
  hospitalLocked: { type: Boolean, default: false },
  status: {
    type: String,
    enum: ['active', 'patientOnBoard', 'complete'],
    default: 'active',
  },
}, { timestamps: true });

module.exports = mongoose.model('Case', caseSchema);
