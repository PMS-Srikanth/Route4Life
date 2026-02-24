const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const connectDB = require('./config/db');

dotenv.config();
connectDB();

const app = express();

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

app.use(cors());
app.use(express.json());

// Serve uploaded audio files
app.use('/uploads', express.static(uploadsDir));

// Serve React hospital dashboard (built with Vite → hospital-dashboard/dist)
const dashboardDist = path.join(__dirname, '../hospital-dashboard/dist');
const dashboardHtml = path.join(__dirname, '../hospital-dashboard/index.html');
if (fs.existsSync(dashboardDist)) {
  app.use('/dashboard', express.static(dashboardDist));
  app.get('/dashboard/*', (req, res) =>
    res.sendFile(path.join(dashboardDist, 'index.html'))
  );
} else if (fs.existsSync(dashboardHtml)) {
  // Plain HTML dashboard (no build step)
  app.get('/dashboard', (req, res) => res.sendFile(dashboardHtml));
}

// Routes
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/hospitals', require('./routes/hospital.routes'));
app.use('/api/request', require('./routes/request.routes'));
app.use('/api/cases', require('./routes/case.routes'));

// Health check
app.get('/', (req, res) => res.json({ message: 'Route4Life API running' }));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
