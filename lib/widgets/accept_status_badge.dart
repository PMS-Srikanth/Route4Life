import 'package:flutter/material.dart';
import '../models/request_model.dart';

class AcceptStatusBadge extends StatelessWidget {
  final RequestStatus status;

  const AcceptStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case RequestStatus.accepted:
        color = Colors.green;
        label = 'Accepted';
        break;
      case RequestStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
        break;
      case RequestStatus.timeout:
        color = Colors.orange;
        label = 'Timeout';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
