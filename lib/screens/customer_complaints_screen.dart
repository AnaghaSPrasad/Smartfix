import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../services/api_service.dart';

class CustomerComplaintsScreen extends StatefulWidget {
  const CustomerComplaintsScreen({super.key});

  @override
  State<CustomerComplaintsScreen> createState() => _CustomerComplaintsScreenState();
}

class _CustomerComplaintsScreenState extends State<CustomerComplaintsScreen> {
  final ApiService _api = ApiService();
  late Future<List<Complaint>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _complaintsFuture = _api.getComplaints();
  }

  Future<void> _refresh() async {
    _load();
    setState(() {});
    await _complaintsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Complaints')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Complaint>>(
          future: _complaintsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load your complaints.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final complaints = snapshot.data ?? [];
            if (complaints.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                        SizedBox(height: 12),
                        Text('No complaints yet.'),
                        SizedBox(height: 6),
                        Text(
                          'Any complaint you submit will appear here with its resolution.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: complaints.length,
              itemBuilder: (context, index) => _buildComplaintCard(complaints[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    final isResolved = complaint.status == 'resolved';
    final statusColor = isResolved ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isResolved ? Icons.task_alt : Icons.hourglass_top, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    complaint.bookingSummary,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Chip(
                  label: Text(isResolved ? 'Resolved' : 'Under review'),
                  labelStyle: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Your complaint', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(complaint.description),
            if (isResolved) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mark_email_read, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Resolution from SmartFix',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complaint.adminNote.isNotEmpty
                          ? complaint.adminNote
                          : 'Your complaint has been reviewed and resolved by the SmartFix admin team.',
                      style: const TextStyle(height: 1.35),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Our admin team is reviewing your complaint. Refresh this page for updates.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
