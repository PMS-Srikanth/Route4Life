import 'package:flutter/material.dart';
import '../controllers/case_controller.dart';
import '../widgets/hospital_card.dart';
import 'navigation_to_hospital_screen.dart';

class HospitalConfirmationScreen extends StatelessWidget {
  final CaseController caseController;

  const HospitalConfirmationScreen({
    super.key,
    required this.caseController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Hospital'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: caseController,
        builder: (_, __) {
          final ranked = caseController.rankedHospitals;
          final assigned = caseController.assignedHospital;

          if (ranked.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Hospital to Proceed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: ranked.length,
                  itemBuilder: (_, i) {
                    final h = ranked[i];
                    return HospitalCard(
                      hospital: h,
                      isSelected: assigned?.id == h.id,
                      onTap: () {
                        caseController.assignedHospital = h;
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: assigned == null
                        ? null
                        : () {
                            caseController.confirmPickup();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NavigationToHospitalScreen(
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
                      'Confirm & Start to Hospital',
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
