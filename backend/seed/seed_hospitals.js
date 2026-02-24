require('dotenv').config({ path: '../.env' });
const mongoose = require('mongoose');
const Hospital = require('../models/Hospital');
const Driver = require('../models/Driver');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/route4life';

// ─────────────────────────────────────────────────────────────────────────────
// VERIFIED Vijayawada Hospitals — GPS coordinates from Google Maps (2026)
// All city hospitals are within 10 km of city centre (16.5062, 80.6480).
// NH-16 hospitals appear only when the 20 km expansion radius is triggered.
// ─────────────────────────────────────────────────────────────────────────────
const hospitals = [
  // ── City hospitals (within 10 km) ─────────────────────────────────────────
  {
    name: 'Government General Hospital (GGH)',
    address: 'Eluru Rd, Governorpet, Vijayawada – 520002',
    lat: 16.5161, lng: 80.6174,
    icuAvailable: true, doctorAvailable: true, icuBeds: 30,
    ventilatorAvailable: true, oxygenAvailable: true, bloodBankAvailable: true,
    phone: '0866-2571919',
    assignedEmail: 'team@route4life.com',  // ← replace with your email
  },
  {
    name: 'Aster Ramesh Hospitals (MG Road)',
    address: 'MG Rd, Opp. Indira Gandhi Stadium, Vijayawada',
    lat: 16.5028, lng: 80.6389,
    icuAvailable: true, doctorAvailable: true, icuBeds: 20,
    ventilatorAvailable: true, oxygenAvailable: true, bloodBankAvailable: true,
    phone: '0866-2472000',
    assignedEmail: 'team@route4life.com',
  },
  {
    name: 'Help Hospitals',
    address: 'MG Rd, Behind Bapu Museum, Vijayawada',
    lat: 16.5089, lng: 80.6274,
    icuAvailable: true, doctorAvailable: true, icuBeds: 15,
    ventilatorAvailable: false, oxygenAvailable: true, bloodBankAvailable: false,
    phone: '0866-6615552',
    assignedEmail: 'team@route4life.com',
  },
  {
    name: 'Andhra Hospitals',
    address: 'CVR Complex, 29-14-61 Sheshadri Sastry St, Vijayawada',
    lat: 16.5111, lng: 80.6295,
    icuAvailable: true, doctorAvailable: true, icuBeds: 18,
    ventilatorAvailable: true, oxygenAvailable: true, bloodBankAvailable: true,
    phone: '0866-2574757',
    assignedEmail: 'team@route4life.com',
  },
  {
    name: 'Vijaya Super Speciality Hospital',
    address: '29-26-92A, Bolivar St, Vijayawada',
    lat: 16.5137, lng: 80.6373,
    icuAvailable: true, doctorAvailable: true, icuBeds: 10,
    ventilatorAvailable: false, oxygenAvailable: true, bloodBankAvailable: false,
    phone: '09440144477',
    assignedEmail: 'team@route4life.com',
  },
  {
    name: 'Manipal Hospital Vijayawada',
    address: '12-570, Near Kanakadurga Varadhi, Vijayawada',
    lat: 16.4845, lng: 80.6170,
    icuAvailable: true, doctorAvailable: true, icuBeds: 22,
    ventilatorAvailable: true, oxygenAvailable: true, bloodBankAvailable: true,
    phone: '18001024647',
    assignedEmail: 'kareeswarbalaji@gmail.com',
  },
  {
    name: 'Kamineni Hospitals',
    address: '100 Feet Rd, New Autonagar, Vijayawada',
    lat: 16.4959, lng: 80.7031,
    icuAvailable: true, doctorAvailable: true, icuBeds: 25,
    ventilatorAvailable: true, oxygenAvailable: true, bloodBankAvailable: true,
    phone: '0866-2463333',
    assignedEmail: 'team@route4life.com',
  },
  {
    name: 'Andhra Hospitals – Bhavanipuram',
    address: 'Opp. ZP High School, Moulangar Masjid Rd, Bhavanipuram',
    lat: 16.5363, lng: 80.5847,
    icuAvailable: true, doctorAvailable: true, icuBeds: 12,
    ventilatorAvailable: false, oxygenAvailable: true, bloodBankAvailable: false,
    phone: '0866-2415757',
    assignedEmail: 'team@route4life.com',
  },
  // ── NH-16 corridor (20 km expansion radius) ───────────────────────────────
  {
    name: 'Pinnamaneni Siddharth Hospital',
    address: 'NH-16, Gannavaram, Near Vijayawada Airport',
    lat: 16.5403, lng: 80.8006,
    icuAvailable: true, doctorAvailable: true, icuBeds: 10,
    ventilatorAvailable: false, oxygenAvailable: true, bloodBankAvailable: false,
    phone: '0866-2340066',
    assignedEmail: 'team@route4life.com',
  },
  {
    name: 'NRI Academy of Medical Sciences',
    address: 'Chinakakani Village, Guntur District (NH-16)',
    lat: 16.2334, lng: 80.8025,
    icuAvailable: true, doctorAvailable: true, icuBeds: 30,
    ventilatorAvailable: true, oxygenAvailable: true, bloodBankAvailable: true,
    phone: '08645-246100',
    assignedEmail: 'team@route4life.com',
  },
];

const testDriver = {
  name: 'Ravi Kumar',
  phone: '9999999999',
  password: 'password123',
  vehicleNumber: 'AP39AB1234',  // Vijayawada registration
};

async function seed() {
  await mongoose.connect(MONGO_URI);
  console.log('Connected to MongoDB');

  // Clear existing
  await Hospital.deleteMany({});
  await Driver.deleteMany({});
  console.log('Cleared existing hospitals and drivers');

  // Add hospitals
  const hospitalDocs = hospitals.map(h => ({
    ...h,
    location: { type: 'Point', coordinates: [h.lng, h.lat] },
  }));
  await Hospital.insertMany(hospitalDocs);
  console.log(`Seeded ${hospitals.length} hospitals`);

  // Add test driver
  await Driver.create(testDriver);
  console.log(`Seeded test driver — phone: ${testDriver.phone}, password: ${testDriver.password}`);

  await mongoose.disconnect();
  console.log('Done!');
}

seed().catch(err => {
  console.error('Seed error:', err);
  process.exit(1);
});
