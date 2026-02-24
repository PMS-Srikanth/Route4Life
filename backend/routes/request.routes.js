const express = require('express');
const router = express.Router();
const {
  createRequest,
  getRequestById,
  getRequestsByCase,
  updateRequestStatus,
  respondToRequest,
} = require('../controllers/request.controller');

router.post('/', createRequest);                      // POST /api/request
router.get('/case/:caseId', getRequestsByCase);       // GET /api/request/case/:caseId
router.get('/:id/respond', respondToRequest);         // GET /api/request/:id/respond?action=accept|reject
router.get('/:id', getRequestById);                   // GET /api/request/:id
router.patch('/:id', updateRequestStatus);            // PATCH /api/request/:id

module.exports = router;
