const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const connectDB = require('./config/db');

dotenv.config();
connectDB();

const app = express();

app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/hospitals', require('./routes/hospital.routes'));
app.use('/api/request', require('./routes/request.routes'));
app.use('/api/cases', require('./routes/case.routes'));

// Health check
app.get('/', (req, res) => res.json({ message: 'Route4Life API running' }));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
