const express = require('express');
const multer = require('multer');
const path = require('path');
const router = express.Router();
const {
  createRequest,
  getRequestById,
  getRequestsByCase,
  getAllRequests,
  updateRequestStatus,
  updateTodo,
  respondToRequest,
  updateVitals,
} = require('../controllers/request.controller');

// Multer — save audio files to uploads/
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '../uploads')),
  filename: (req, file, cb) => cb(null, `audio_${Date.now()}.m4a`),
});
const upload = multer({ storage, limits: { fileSize: 20 * 1024 * 1024 } }); // 20 MB

router.post('/', upload.single('audio'), createRequest); // POST /api/request
router.get('/', getAllRequests);                           // GET  /api/request (dashboard)
router.get('/case/:caseId', getRequestsByCase);            // GET  /api/request/case/:caseId
router.get('/:id/respond', respondToRequest);              // GET  /api/request/:id/respond?action=
router.get('/:id', getRequestById);                        // GET  /api/request/:id
router.patch('/:id/vitals', updateVitals);                  // PATCH /api/request/:id/vitals
router.patch('/:id/todo/:todoIndex', updateTodo);          // PATCH /api/request/:id/todo/:i
router.patch('/:id', updateRequestStatus);                 // PATCH /api/request/:id

module.exports = router;
