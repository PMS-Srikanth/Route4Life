enum AppState {
  idle,
  navigatingToPatient,
  nearPatient,       // within 500m — re-ranking triggered
  patientOnBoard,    // patient picked up, locked hospital
  navigatingToHospital,
  caseComplete,
}
