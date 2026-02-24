const cases = {};

function createCase({ latitude, longitude, description }) {
  const caseId = `CASE_${Date.now()}`;

  cases[caseId] = {
    caseId,
    latitude,
    longitude,
    description,
    status: "CREATED",
    createdAt: new Date().toISOString()
  };

  return cases[caseId];
}

function getCase(caseId) {
  return cases[caseId] || null;
}

module.exports = {
  createCase,
  getCase
};