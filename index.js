const express = require("express");
const bodyParser = require("body-parser");
const { createCase, getCase } = require("./caseManager");

const app = express();
app.use(bodyParser.json());

app.post("/create-case", (req, res) => {
  const { latitude, longitude, description } = req.body;

  if (!latitude || !longitude) {
    return res.status(400).json({ error: "Location required" });
  }

  const newCase = createCase({ latitude, longitude, description });

  res.status(200).json({
    message: "Case created successfully",
    caseId: newCase.caseId
  });
});

app.get("/case/:caseId", (req, res) => {
  const { caseId } = req.params;
  const caseData = getCase(caseId);

  if (!caseData) {
    return res.status(404).json({ error: "Case not found" });
  }

  res.status(200).json(caseData);
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});