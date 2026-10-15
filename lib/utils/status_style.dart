import 'package:flutter/material.dart';

/// Shared color + label helpers so every screen shows booking status consistently.
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'assigned':
      return Colors.blue;
    case 'accepted':
      return Colors.indigo;
    case 'on_the_way':
      return const Color(0xFF00897B); // Teal 600
    case 'arrived':
      return const Color(0xFFE65100); // Deep Orange
    case 'in_progress':
      return Colors.purple;
    case 'completed':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Pending';
    case 'assigned':
      return 'Assigned';
    case 'accepted':
      return 'Worker Accepted';
    case 'on_the_way':
      return 'On the Way';
    case 'arrived':
      return 'Arrived';
    case 'in_progress':
      return 'Work Started';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Chip(
      label: Text(
        statusLabel(status),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

Color complaintStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'submitted':
      return const Color(0xFF1976D2); // Blue
    case 'under_review':
    case 'open':
      return const Color(0xFFF57C00); // Orange
    case 'replied':
      return const Color(0xFF7B1FA2); // Purple
    case 'resolved':
      return const Color(0xFF388E3C); // Green
    case 'closed':
      return const Color(0xFF616161); // Grey
    default:
      return Colors.grey;
  }
}

String complaintStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'submitted':
      return 'Submitted';
    case 'under_review':
    case 'open':
      return 'Under Review';
    case 'replied':
      return 'Replied';
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    default:
      return status;
  }
}

class ComplaintStatusChip extends StatelessWidget {
  final String status;
  const ComplaintStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = complaintStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        complaintStatusLabel(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
