import 'package:flutter/material.dart';

class DistanceIndicator extends StatelessWidget {
  final double distanceMeters;
  final String label;

  const DistanceIndicator({
    super.key,
    required this.distanceMeters,
    this.label = '',
  });

  String get _displayText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.straighten, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          label.isEmpty ? _displayText : '$label: $_displayText',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}
