const mongoose = require('mongoose');

const requestSchema = new mongoose.Schema({
  caseId: { type: String, required: true },
  hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true },
  emergencyType: { type: String, default: 'Critical' },
  vehicleNumber: { type: String },
  distanceKm: { type: Number },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected', 'timeout'],
    default: 'pending',
  },
  // Patient vitals collected in ambulance
  vitals: {
    heartRate: Number,
    bloodPressure: String,
    spo2: Number,
    consciousness: { type: String, default: 'Alert' },
    conditionNotes: String,
  },
  audioUrl: { type: String },        // served from /uploads/
  todos: [
    {
      task: { type: String, required: true },
      completed: { type: Boolean, default: false },
    },
  ],
}, { timestamps: true });

module.exports = mongoose.model('Request', requestSchema);
