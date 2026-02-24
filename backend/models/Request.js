const mongoose = require('mongoose');

const requestSchema = new mongoose.Schema({
  caseId: { type: String, required: true },
  hospitalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hospital', required: true },
  emergencyType: { type: String, default: 'Critical' },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected', 'timeout'],
    default: 'pending',
  },
}, { timestamps: true });

module.exports = mongoose.model('Request', requestSchema);
