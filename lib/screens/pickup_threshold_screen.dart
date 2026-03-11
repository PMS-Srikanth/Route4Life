import 'package:flutter/material.dart';
import '../controllers/case_controller.dart';
import '../widgets/hospital_card.dart';
import 'hospital_confirmation_screen.dart';

/// Triggered when driver is within 500m of patient.
/// Shows re-ranked hospitals and prompts driver to confirm pickup.
class PickupThresholdScreen extends StatelessWidget {
  final CaseController caseController;

  const PickupThresholdScreen({super.key, required this.caseController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Near Patient — Re-ranking'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: caseController,
        builder: (_, __) {
          final ranked = caseController.rankedHospitals;

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFFEBEE),
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Color(0xFFE53935)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are within 500m of the patient.\nBest hospitals have been re-ranked.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE53935)),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Re-Ranked Hospitals (Nearest First)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: ranked.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: ranked.length,
                        itemBuilder: (_, i) => HospitalCard(
                          hospital: ranked[i],
                          isSelected:
                              caseController.assignedHospital?.id ==
                                  ranked[i].id,
                          onTap: () {
                            caseController.assignedHospital = ranked[i];
                          },
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HospitalConfirmationScreen(
                            caseController: caseController,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Patient Picked Up — Confirm Hospital',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
