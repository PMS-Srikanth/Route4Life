const mongoose = require('mongoose');

const hospitalSchema = new mongoose.Schema({
  name: { type: String, required: true },
  address: { type: String, default: '' },
  // GeoJSON point for geospatial queries
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true }, // [lng, lat]
  },
  // Flat lat/lng for simple distance calc in Flutter
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  icuAvailable: { type: Boolean, default: false },
  doctorAvailable: { type: Boolean, default: false },
  icuBeds: { type: Number, default: 0 },
  ventilatorAvailable: { type: Boolean, default: false },
  oxygenAvailable: { type: Boolean, default: true },
  bloodBankAvailable: { type: Boolean, default: false },
  phone: { type: String, default: '' },
  // Assigned team email — receives doctor-availability request notifications
  assignedEmail: { type: String, default: '' },
}, { timestamps: true });

hospitalSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Hospital', hospitalSchema);
