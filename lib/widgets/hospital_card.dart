import 'package:flutter/material.dart';
import '../models/hospital_model.dart';

class HospitalCard extends StatelessWidget {
  final HospitalModel hospital;
  final bool isSelected;
  final VoidCallback? onTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEBEE) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFFE53935) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_hospital,
                      color: Color(0xFFE53935), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hospital.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Color(0xFFE53935), size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text(hospital.address,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _badge(
                    hospital.icuAvailable ? 'ICU ✓' : 'ICU ✗',
                    hospital.icuAvailable ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  _badge(
                    hospital.doctorAvailable ? 'Doctor ✓' : 'Doctor ✗',
                    hospital.doctorAvailable ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  _badge('${hospital.icuBeds} beds', Colors.blue),
                  if (hospital.distanceFromPatient != null) ...[
                    const Spacer(),
                    Text(
                      hospital.distanceFromPatient! >= 1000
                          ? '${(hospital.distanceFromPatient! / 1000).toStringAsFixed(1)} km'
                          : '${hospital.distanceFromPatient!.toInt()} m',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE53935)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _badge(
                    hospital.ventilatorAvailable ? 'Ventilator ✓' : 'Ventilator ✗',
                    hospital.ventilatorAvailable ? Colors.teal : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  _badge(
                    hospital.oxygenAvailable ? 'O₂ ✓' : 'O₂ ✗',
                    hospital.oxygenAvailable ? Colors.teal : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  _badge(
                    hospital.bloodBankAvailable ? 'Blood Bank ✓' : 'Blood Bank ✗',
                    hospital.bloodBankAvailable ? Colors.teal : Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child:
          Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
