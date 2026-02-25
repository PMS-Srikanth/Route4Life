# Route4Life 🚑

**An intelligent ambulance dispatch and routing system** built for emergency response — connecting ambulance drivers with the nearest available hospitals in real time, with live patient vitals monitoring and hospital preparation alerts.

> Built as a Hackathon project by using Flutter, Node.js, MongoDB, Firebase, and Google Maps.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Setup — Backend](#setup--backend)
- [Setup — Flutter App](#setup--flutter-app)
- [Setup — Hospital Dashboard](#setup--hospital-dashboard)
- [Running the App](#running-the-app)
- [How It Works — Step by Step](#how-it-works--step-by-step)
- [Hospital Ranking Algorithm](#hospital-ranking-algorithm)
- [API Endpoints](#api-endpoints)
- [Firebase Configuration](#firebase-configuration)
- [Environment Variables](#environment-variables)
- [Known Issues & Notes](#known-issues--notes)

---

## Overview

Route4Life is a full-stack mobile application that solves a critical problem in emergency healthcare: **getting ambulance patients to the right hospital as fast as possible**.

When an ambulance picks up a patient, the driver:
1. Logs in via Firebase phone OTP
2. Enters patient details and location
3. The app automatically contacts **all nearby ranked hospitals** simultaneously
4. Patient vitals are continuously sent to the accepting hospital every 20 seconds
5. The hospital dashboard shows live vitals and preparation checklists
6. Google Maps turn-by-turn navigation guides the driver to the hospital

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Flutter App (Driver)                      │
│  Login → Dashboard → Nearby Hospitals → Navigation → Done  │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP REST API
                     ▼
┌─────────────────────────────────────────────────────────────┐
│             Node.js / Express Backend (Port 5000)           │
│  Auth │ Hospitals │ Requests │ Cases │ Vitals │ Email       │
└────────────────────┬────────────────────────────────────────┘
                     │ Mongoose ODM
                     ▼
              ┌─────────────┐
              │   MongoDB   │
              └─────────────┘

┌─────────────────────────────────────────────────────────────┐
│          Hospital Dashboard (HTML / JavaScript)             │
│  index.html (generic) │ manipal.html (Manipal Hospital)    │
│  Polls backend every 4s │ Accept/Reject │ Vitals display   │
└─────────────────────────────────────────────────────────────┘

              ┌─────────────────┐
              │  Firebase Auth  │  ← Phone OTP verification
              └─────────────────┘

              ┌─────────────────┐
              │  Google Maps    │  ← Maps + Directions API
              └─────────────────┘
```

---

## Features

### 🔐 Authentication
- Firebase Phone OTP login (Indian mobile numbers, +91 prefix auto-added)
- Auto SMS retrieval on Android (no manual OTP entry needed)
- Full error handling: invalid number, too many requests, network failures

### 🗺️ Dashboard
- Patient name, phone, latitude, longitude input
- Voice-to-text patient name capture (audio recording)
- "View Nearby Hospitals" uses **patient** coordinates (not driver GPS)
- Driver GPS used only as fallback if patient location fields are empty

### 🏥 Nearby Hospitals & Smart Dispatch
- Lists hospitals in Vijayawada sorted by a multi-factor **ranking algorithm**
- **Auto-sends requests to ALL hospitals** on screen load — no manual tap needed
- Live banner shows "📡 Automatically contacting all hospitals…"
- Each hospital card shows: name, distance, ETA, availability, rank score
- Manual "Send Request" button available for any hospital in the list

### 💓 Live Patient Vitals
- Vitals screen **auto-fills defaults** when opened: HR `82 bpm`, BP `118/76 mmHg`, SpO₂ `97%`, Consciousness `Alert` — driver can edit before submitting
- Vitals screen captures: Heart Rate (bpm), Blood Pressure (systolic/diastolic), SpO₂ (%)
- Vitals **auto-drift** every 20 seconds with realistic random variation:
  - Heart Rate: ±3 bpm
  - Blood Pressure: ±5 systolic / ±3 diastolic mmHg
  - SpO₂: ±1%
- Vitals pushed to all active/pending hospital requests via `PATCH /api/request/:id/vitals`

### 🚦 Hospital Request Flow
- Hospitals receive requests on their dashboard (polls every 4 seconds)
- **Accept / Reject** buttons with audio feedback
- Accepting triggers: email notification to hospital + navigation start for driver
- Rejected requests auto-escalate to the next ranked hospital

### 📧 Email Notifications
- Nodemailer sends an email to the hospital on request acceptance
- Email includes patient name, vitals, ambulance ETA, and driver contact

### 🧭 Turn-by-Turn Navigation
- Uses `com.google.android.apps.maps` intent to open Google Maps with full navigation
- Route: Driver current location → Patient location → Hospital
- Falls back to `url_launcher` web Maps if native Maps is not installed

### ✅ Hospital Preparation Checklist
- Hospital dashboard shows ER prep tasks: assign trauma bay, IV access, O₂/AED, BP/ECG, notify physician
- Checkboxes are **disabled and locked** until the hospital accepts the request
- Warning shown: "⚠️ Accept this request to enable preparation checklist"
- Tasks auto-generated per case type by `todoGenerator.js`

### 📍 Case Completion
- Driver taps "Arrived at Hospital" → case marked complete
- Full case summary screen shown (Case Complete Screen)
- Case stored in MongoDB for audit trail

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter 3.41.1 (Dart) |
| Authentication | Firebase Auth v5 (Phone OTP) |
| Maps & Navigation | Google Maps Flutter, Google Directions API |
| Location | Geolocator (GPS) |
| Backend | Node.js + Express.js |
| Database | MongoDB + Mongoose |
| Email | Nodemailer (Gmail SMTP) |
| Hospital Dashboard | Vanilla HTML + CSS + JavaScript |
| Audio Input | `record` package (voice-to-text for patient name) |

---

## Project Structure

```
Route4Life/
├── lib/                                    # Flutter app source
│   ├── main.dart                           # App entry point, Firebase init
│   ├── core/
│   │   └── constants.dart                  # Backend URL, API keys
│   ├── models/
│   │   ├── driver_model.dart
│   │   ├── hospital_model.dart
│   │   ├── request_model.dart
│   │   ├── vitals_model.dart
│   │   ├── case_model.dart
│   │   └── route_model.dart
│   ├── screens/
│   │   ├── login_screen.dart               # Firebase OTP login
│   │   ├── dashboard_screen.dart           # Patient info entry
│   │   ├── nearby_hospitals_screen.dart    # Hospital list + auto-dispatch
│   │   ├── patient_vitals_screen.dart      # Vitals capture
│   │   ├── navigation_to_patient_screen.dart
│   │   ├── navigation_to_hospital_screen.dart
│   │   ├── hospital_confirmation_screen.dart
│   │   ├── pickup_threshold_screen.dart
│   │   ├── in_app_navigation_screen.dart
│   │   └── case_complete_screen.dart
│   ├── services/
│   │   ├── firebase_auth_service.dart      # OTP send / verify
│   │   ├── auth_service.dart
│   │   ├── hospital_service.dart           # Fetch hospitals from backend
│   │   ├── request_service.dart            # Send requests, push vitals
│   │   ├── location_service.dart           # GPS utilities
│   │   ├── ranking_service.dart            # Hospital scoring algorithm
│   │   ├── navigation_service.dart         # Google Maps launcher
│   │   ├── route_service.dart              # Directions API
│   │   └── api_service.dart
│   ├── controllers/
│   └── widgets/
│
├── backend/                                # Node.js API server
│   ├── server.js                           # Express app, MongoDB connect
│   ├── .env                                # Environment config (not committed)
│   ├── config/
│   │   └── db.js                           # MongoDB connection
│   ├── controllers/
│   │   ├── auth.controller.js              # Driver login / register
│   │   ├── hospital.controller.js          # Hospital CRUD
│   │   ├── request.controller.js           # Request lifecycle + vitals update
│   │   └── case.controller.js              # Case creation / completion
│   ├── models/
│   ├── routes/
│   ├── utils/
│   │   ├── todoGenerator.js                # Auto-generate ER prep tasks
│   │   └── mailer.js                       # Nodemailer email utility
│   └── seed/
│       └── seed_hospitals.js               # Seeds Vijayawada hospital data
│
├── hospital-dashboard/                     # Hospital web interface
│   ├── index.html                          # Generic hospital dashboard
│   └── manipal.html                        # Manipal Hospital specific view
│
└── android/
    └── app/
        └── google-services.json            # Firebase Android config
```

---

## Prerequisites

### For the Backend
- **Node.js** v18+ — https://nodejs.org
- **MongoDB** running locally on `mongodb://localhost:27017` OR a MongoDB Atlas URI
- **npm** (comes with Node.js)

### For the Flutter App
- **Flutter SDK** 3.41.1 — https://docs.flutter.dev/get-started/install
- **Android Studio** with Android SDK installed
- **Java JDK 17+**
- A physical Android device (recommended) or emulator with Google Play Services
- USB debugging enabled on the device

### API Keys Needed
- **Google Maps Android API Key** — enable in Google Cloud Console:
  - Maps SDK for Android
  - Directions API
  - Places API
- **Firebase Project** with Phone Authentication enabled

---

## Setup — Backend

### 1. Install dependencies
```bash
cd backend
npm install
```

### 2. Create `.env` file inside `backend/`
```env
PORT=5000
MONGO_URI=mongodb://localhost:27017/route4life
JWT_SECRET=your_jwt_secret_here
EMAIL_USER=your_gmail@gmail.com
EMAIL_PASS=your_gmail_app_password
```

> For `EMAIL_PASS`, use a Gmail **App Password** (not your regular password).  
> Go to https://myaccount.google.com → Security → 2-Step Verification → App passwords → Generate.

### 3. Seed hospital data (Vijayawada hospitals pre-loaded)
```bash
npm run seed
```

### 4. Start the backend
```bash
# Production start
npm start

# Development (auto-restart on file change)
npm run dev
```

Backend runs on `http://localhost:5000`. Confirm you see:
```
MongoDB connected
Server running on port 5000
```

---

## Setup — Flutter App

### 1. Find your machine's local IP address

The phone needs to reach your PC's backend over the local network.

```powershell
# Windows PowerShell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } | Select-Object InterfaceAlias, IPAddress
```
```bash
# Linux / macOS
ifconfig | grep "inet "
```

Note the IP (e.g., `10.21.130.199`). The phone and PC **must be on the same WiFi network**.

### 2. Update the backend URL
Edit `lib/core/constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_PC_IP:5000/api';
// Example:
static const String baseUrl = 'http://10.21.130.199:5000/api';
```

### 3. Add Google Maps API key
Edit `android/app/src/main/AndroidManifest.xml`, inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### 4. Firebase setup
1. Go to https://console.firebase.google.com → Your project
2. Project Settings → Android App → package name `com.route4life.route4life`
3. Add fingerprints. Get them by running:
   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
4. Add both **SHA-1** and **SHA-256** fingerprints shown in the output
5. Enable **Phone Authentication**: Authentication → Sign-in method → Phone → Enable
6. Download `google-services.json` and place it at `android/app/google-services.json`

### 5. Install Flutter dependencies
```bash
flutter pub get
```

### 6. Connect your Android device
- Enable **Developer Options** on your phone (tap Build Number 7 times in About Phone)
- Enable **USB Debugging**
- Connect via USB
- Confirm device is detected:
  ```bash
  flutter devices
  ```

### 7. Build and run
```bash
# Run directly (hot reload enabled)
flutter run -d <device-id>

# Or build APK and install manually
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.route4life.route4life/.MainActivity
```

---

## Setup — Hospital Dashboard

The dashboard is plain HTML — no build step required.

1. Open `hospital-dashboard/manipal.html` in Chrome or Edge
2. Update the `API_BASE` URL at the top of the file:
   ```javascript
   const API_BASE = 'http://10.21.130.199:5000/api';  // your PC's IP
   ```
3. Open the file. It polls for new requests every **4 seconds** automatically.

For demo, keep this open on a laptop/second screen while the Flutter app runs on the phone.

---

## Running the App

### Full Demo Setup (3 steps, 3 windows)

**Step 1 — Start Backend**
```bash
cd backend
node server.js
```
Confirm: `MongoDB connected` + `Server running on port 5000`

**Step 2 — Open Hospital Dashboard**
- Open `hospital-dashboard/manipal.html` in your browser
- Dashboard waits for incoming requests

**Step 3 — Launch Flutter App**
```bash
flutter run -d <device-id>
```

### Complete Demo Flow
1. **Login Screen** — Enter 10-digit mobile number → OTP sent via Firebase
2. Enter the 6-digit OTP → Logged in
3. **Dashboard Screen** — Fill: Patient Name, Phone, Latitude, Longitude
4. Tap **"View Nearby Hospitals"** → hospitals ranked and listed
5. App **auto-sends requests to all hospitals** immediately (no button needed)
6. **Hospital Dashboard** shows the incoming request → Click **Accept**
7. Driver app triggers **Google Maps navigation** to patient location
8. Driver arrives at patient → taps **"Picked Up"** → enters vitals (HR, BP, SpO₂)
9. Vitals appear on hospital dashboard and **auto-update every 20 seconds**
10. Driver follows navigation to hospital
11. Driver taps **"Arrived at Hospital"** → Case marked complete ✅

---

## How It Works — Step by Step

### 1. Authentication (`login_screen.dart`, `firebase_auth_service.dart`)
- User enters 10-digit number → prefixed with `+91` → passed to Firebase
- `FirebaseAuth.verifyPhoneNumber()` triggers Play Integrity / reCAPTCHA check server-side
- On success: Firebase sends SMS OTP
- Android SMS Retriever API auto-fills OTP if app hash is configured
- On verify: `PhoneAuthProvider.credential()` created → `signInWithCredential()`
- Backend called to fetch/create driver profile from `uid`

### 2. Patient Info Entry (`dashboard_screen.dart`)
- Fields: patient name (text or voice), phone, lat/lng
- "View Nearby Hospitals" reads lat/lng from input fields — uses patient location, not driver GPS
- Falls back to driver GPS only if both fields are blank

### 3. Hospital Ranking & Auto-Dispatch (`ranking_service.dart`, `nearby_hospitals_screen.dart`)
- `GET /api/hospitals` fetches all hospitals from MongoDB
- Each hospital scored by weighted algorithm (distance, availability, specialisation, response time, load)
- Sorted descending — best hospital is index 0
- `_autoSendInitialRequests()` runs on `initState()`:
  - Sends `POST /api/request` for **every hospital** in the ranked list with status `pending`
  - Banner displayed: "📡 Automatically contacting all hospitals…"

### 4. Request Lifecycle (`request.controller.js`)
- `POST /api/request` — creates request, stores patient info + vitals + hospitalId
- Hospital dashboard calls `GET /api/request/pending?hospitalId=...` every 4s
- Hospital Accept → `PATCH /api/request/:id/status` → `{ status: "accepted" }`
- On accept: `mailer.js` sends email; Flutter detects accepted status via polling → launches navigation
- Hospital Reject → Flutter's `_autoRequestBetterRankedHospitals()` sends to next ranked hospital

### 5. Live Vitals Push (`patient_vitals_screen.dart`, `request_service.dart`)
- Vitals screen opens with pre-filled defaults (HR: 82, BP: 118/76, SpO₂: 97, Consciousness: Alert) — editable before submission
- Initial vitals entered/confirmed by driver after patient pickup
- `_startVitalsUpdater()` — `Timer.periodic(20 seconds)`
- Each tick: `_varyVitals()` adds realistic random drift to values
- `RequestService.pushVitals(requestId, vitals)` — PATCH to backend
- Backend `updateVitals()` controller: `$set: { vitals: req.body }` on the request document
- Hospital dashboard reads updated vitals from the request object every 4s poll

### 6. Navigation (`navigation_service.dart`)
- Builds URI: `geo:LAT,LNG?q=LAT,LNG` or `google.navigation:q=LAT,LNG&mode=d`
- `canLaunchUrl` checks if Google Maps is installed
- If available: opens native Maps with driving navigation
- If not: falls back to `https://maps.google.com/?daddr=LAT,LNG`

---

## Hospital Ranking Algorithm

Each hospital is scored on 5 factors (weighted sum):

| Factor | Weight | Description |
|--------|--------|-------------|
| Distance | 40% | Inverse of km distance — closer = higher score |
| Availability | 25% | Available beds / ICU availability flag |
| Specialisation match | 20% | Does the hospital handle the case type (trauma, cardiac, etc.) |
| Historical response time | 10% | Faster-accepting hospitals ranked higher over time |
| Current load | 5% | Hospitals with fewer active cases preferred |

**Formula:**
```
score = (0.40 × distanceScore)
      + (0.25 × availabilityScore)
      + (0.20 × specialisationScore)
      + (0.10 × responseTimeScore)
      + (0.05 × loadScore)
```

All sub-scores are normalised to [0, 1] before applying weights.

---

## API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register a new driver |
| POST | `/api/auth/login` | Login, returns JWT token |
| GET | `/api/auth/driver/:uid` | Get driver profile by Firebase UID |

### Hospitals
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/hospitals` | List all hospitals |
| GET | `/api/hospitals/:id` | Get single hospital by ID |
| GET | `/api/hospitals/nearby?lat=&lng=&radius=` | Hospitals within radius (km) |

### Requests
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/request` | Create new hospital request |
| GET | `/api/request/pending?hospitalId=` | Pending requests for a hospital |
| PATCH | `/api/request/:id/status` | Update status (accepted / rejected) |
| PATCH | `/api/request/:id/vitals` | Push updated patient vitals |
| GET | `/api/request/:id` | Get full request details |

### Cases
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/case` | Create a new case record |
| PATCH | `/api/case/:id/complete` | Mark case as complete |
| GET | `/api/case/:id` | Get case details |

---

## Firebase Configuration

### `android/app/google-services.json`
Download from Firebase Console after configuring the Android app.

**Required steps in Firebase Console:**
1. Project Settings → Add Android App → package name: `com.route4life.route4life`
2. Add **SHA-1** fingerprint (from `keytool` command above)
3. Add **SHA-256** fingerprint (from same `keytool` output)
4. Authentication → Sign-in method → **Phone → Enable**
5. Download `google-services.json` → place in `android/app/`

### Test Phone Numbers (demo without real SMS)
For presentations where real SMS isn't needed:

Firebase Console → Authentication → Sign-in method → Phone → **Phone numbers for testing**:
- Add number: `+919999999999`
- Add OTP: `123456`

Use this number in the app to bypass all SMS sending. OTP will always be `123456`.

---

## Environment Variables

### `backend/.env`
```env
PORT=5000
MONGO_URI=mongodb://localhost:27017/route4life
JWT_SECRET=<any long random string, e.g. route4life_secret_2026>
EMAIL_USER=<your gmail address>
EMAIL_PASS=<16-character gmail app password>
```

### `lib/core/constants.dart`
```dart
class AppConstants {
  static const String baseUrl = 'http://10.21.130.199:5000/api'; // update with your PC IP
  static const String googleMapsApiKey = 'AIza...';              // your Maps API key
}
```

---

## Known Issues & Notes

| Issue | Status | Notes |
|-------|--------|-------|
| Firebase OTP `internal-error` | Known | Campus/office WiFi may block Firebase's Play Integrity servers. Use mobile data or add a test phone number in Firebase Console. |
| `google-services.json` has no `certificate_hash` field | By design | Newer Firebase projects validate SHA-1 server-side; it is no longer embedded in the JSON. |
| Backend URL changes when switching networks | Limitation | Update `AppConstants.baseUrl` whenever your PC IP changes. |
| Navigation opens external Google Maps | By design | Uses native Google Maps app for reliable turn-by-turn routing. |
| Audio uploads in `backend/uploads/` | Dev only | In production, use cloud storage (AWS S3 or Google Cloud Storage). |
| Vitals drift is simulated | Demo feature | Real deployment should integrate with medical IoT device APIs. |

---

## Branch Info

- **Main development branch**: `srikanth`
- All features developed, tested, and committed on branch `srikanth`
- Repository: https://github.com/PMS-Srikanth/Route4Life

---

## Author

**Srikanth,Paavan,Eswar,Harini,Pranathi** — Route4Life Hackathon Project, 2026

---

*Built to save lives, one route at a time. 🚑*