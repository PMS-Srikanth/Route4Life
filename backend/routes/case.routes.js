const express = require('express');
const router = express.Router();
const {
  createCase,
  getCaseById,
  lockHospital,
  completeCase,
} = require('../controllers/case.controller');

router.post('/', createCase);                         // POST /api/cases
router.get('/:caseId', getCaseById);                  // GET /api/cases/:caseId
router.patch('/:caseId/lock', lockHospital);          // PATCH /api/cases/:caseId/lock
router.patch('/:caseId/complete', completeCase);      // PATCH /api/cases/:caseId/complete

module.exports = router;
