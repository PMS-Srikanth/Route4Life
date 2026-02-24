const Request = require('../models/Request');
const Hospital = require('../models/Hospital');
const sendMail = require('../utils/mailer');

// POST /api/request
// Flutter sends: { hospitalId, caseId, emergencyType, vehicleNumber?, distanceKm? }
const createRequest = async (req, res) => {
  const { hospitalId, caseId, emergencyType, vehicleNumber, distanceKm } = req.body;

  if (!hospitalId || !caseId) {
    return res.status(400).json({ message: 'hospitalId and caseId are required' });
  }

  try {
    // Check if request already exists for this case+hospital
    const existing = await Request.findOne({ caseId, hospitalId });
    if (existing) {
      return res.json(existing); // Return existing instead of duplicate
    }

    const request = await Request.create({
      caseId,
      hospitalId,
      emergencyType: emergencyType || 'Critical',
      status: 'pending',
    });

    // ── Send email notification to hospital ──────────────────────────────────
    try {
      const hospital = await Hospital.findById(hospitalId);
      if (hospital && hospital.assignedEmail) {
        const timeStr = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
        const distanceText = distanceKm ? `${parseFloat(distanceKm).toFixed(1)} km away` : 'distance unknown';
        const vehicleText = vehicleNumber || 'N/A';

        await sendMail({
          to: hospital.assignedEmail,
          subject: `🚑 Route4Life – Doctor Availability Request for ${hospital.name}`,
          html: `
            <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;border:1px solid #ddd;border-radius:8px;overflow:hidden">
              <div style="background:#e53935;padding:20px;text-align:center">
                <h1 style="color:#fff;margin:0">🚑 Route4Life Emergency Request</h1>
              </div>
              <div style="padding:24px">
                <h2 style="color:#333">A nearby ambulance is requesting doctor availability</h2>
                <table style="width:100%;border-collapse:collapse;margin-top:16px">
                  <tr style="background:#f5f5f5">
                    <td style="padding:10px;font-weight:bold;border:1px solid #ddd">Hospital</td>
                    <td style="padding:10px;border:1px solid #ddd">${hospital.name}</td>
                  </tr>
                  <tr>
                    <td style="padding:10px;font-weight:bold;border:1px solid #ddd">Emergency Type</td>
                    <td style="padding:10px;border:1px solid #ddd;color:#e53935;font-weight:bold">${emergencyType || 'Critical'}</td>
                  </tr>
                  <tr style="background:#f5f5f5">
                    <td style="padding:10px;font-weight:bold;border:1px solid #ddd">Ambulance Vehicle</td>
                    <td style="padding:10px;border:1px solid #ddd">${vehicleText}</td>
                  </tr>
                  <tr>
                    <td style="padding:10px;font-weight:bold;border:1px solid #ddd">Distance</td>
                    <td style="padding:10px;border:1px solid #ddd">${distanceText}</td>
                  </tr>
                  <tr style="background:#f5f5f5">
                    <td style="padding:10px;font-weight:bold;border:1px solid #ddd">Request Time</td>
                    <td style="padding:10px;border:1px solid #ddd">${timeStr}</td>
                  </tr>
                  <tr>
                    <td style="padding:10px;font-weight:bold;border:1px solid #ddd">Request ID</td>
                    <td style="padding:10px;border:1px solid #ddd;font-size:12px;color:#888">${request._id}</td>
                  </tr>
                </table>
                <p style="margin-top:20px;color:#555">Please respond to the ambulance driver <b>immediately</b> by clicking one of the buttons below:</p>
                <div style="text-align:center;margin:24px 0">
                  <a href="http://10.21.130.199:5000/api/request/${request._id}/respond?action=accept"
                     style="background:#2e7d32;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-size:16px;font-weight:bold;margin-right:12px;display:inline-block">
                    ✅ ACCEPT
                  </a>
                  <a href="http://10.21.130.199:5000/api/request/${request._id}/respond?action=reject"
                     style="background:#c62828;color:#fff;padding:14px 32px;border-radius:8px;text-decoration:none;font-size:16px;font-weight:bold;display:inline-block">
                    ❌ REJECT
                  </a>
                </div>
                <p style="color:#999;font-size:12px;margin-top:32px">This is an automated alert from the Route4Life Ambulance Navigation System.</p>
              </div>
            </div>
          `,
        });
      }
    } catch (mailErr) {
      // Don't fail the request if email fails
      console.error('[request.controller] Email send failed:', mailErr.message);
    }

    res.status(201).json(request);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// GET /api/request/:id
const getRequestById = async (req, res) => {
  try {
    const request = await Request.findById(req.params.id);
    if (!request) return res.status(404).json({ message: 'Request not found' });
    res.json(request);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// GET /api/request/case/:caseId  — get all requests for a case
const getRequestsByCase = async (req, res) => {
  try {
    const requests = await Request.find({ caseId: req.params.caseId })
      .populate('hospitalId', 'name address lat lng');
    res.json(requests);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// PATCH /api/request/:id  — hospital updates status (accepted/rejected)
const updateRequestStatus = async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['pending', 'accepted', 'rejected', 'timeout'];

  if (!validStatuses.includes(status)) {
    return res.status(400).json({ message: 'Invalid status' });
  }

  try {
    const request = await Request.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );
    if (!request) return res.status(404).json({ message: 'Request not found' });
    res.json(request);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

module.exports = { createRequest, getRequestById, getRequestsByCase, updateRequestStatus, respondToRequest };

// GET /api/request/:id/respond?action=accept|reject
// Hospital clicks this link from the email
async function respondToRequest(req, res) {
  const { action } = req.query;
  if (!['accept', 'reject'].includes(action)) {
    return res.status(400).send('<h2>Invalid action.</h2>');
  }
  const status = action === 'accept' ? 'accepted' : 'rejected';
  try {
    const request = await Request.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    ).populate('hospitalId', 'name');

    if (!request) return res.status(404).send('<h2>Request not found.</h2>');

    const hospitalName = request.hospitalId?.name || 'Hospital';
    const color = status === 'accepted' ? '#2e7d32' : '#c62828';
    const icon = status === 'accepted' ? '✅' : '❌';
    const word = status === 'accepted' ? 'ACCEPTED' : 'REJECTED';

    res.send(`
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
      <title>Route4Life – Response Recorded</title>
      <style>
        body{font-family:Arial,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5}
        .card{background:#fff;border-radius:12px;padding:40px;text-align:center;max-width:400px;box-shadow:0 4px 20px rgba(0,0,0,.1)}
        .icon{font-size:64px;margin-bottom:16px}
        .status{color:${color};font-size:28px;font-weight:bold;margin-bottom:8px}
        .msg{color:#555;font-size:16px}
        .badge{display:inline-block;background:${color};color:#fff;border-radius:20px;padding:6px 20px;font-size:14px;margin-top:20px}
      </style>
      </head>
      <body>
        <div class="card">
          <div class="icon">${icon}</div>
          <div class="status">${word}</div>
          <div class="msg">${hospitalName} has <b>${status}</b> the ambulance doctor availability request.</div>
          <div class="badge">The ambulance driver has been notified.</div>
          <p style="color:#aaa;font-size:12px;margin-top:24px">Route4Life Ambulance Navigation System</p>
        </div>
      </body>
      </html>
    `);
  } catch (err) {
    res.status(500).send('<h2>Server error. Please try again.</h2>');
  }
}
