import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/complaint.dart';
import '../services/api_service.dart';
import '../utils/status_style.dart';
import 'complaint_screen.dart';

class CustomerComplaintsScreen extends StatefulWidget {
  const CustomerComplaintsScreen({super.key});

  @override
  State<CustomerComplaintsScreen> createState() => _CustomerComplaintsScreenState();
}

class _CustomerComplaintsScreenState extends State<CustomerComplaintsScreen> {
  final ApiService _api = ApiService();
  late Future<List<Complaint>> _complaintsFuture;
  String _statusFilter = 'all'; // 'all', 'under_review', 'replied', 'resolved', 'closed'

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

  Future<void> _openNewComplaint() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ComplaintScreen()),
    );
    if (result == true) {
      _refresh();
    }
  }

  List<Complaint> _filterComplaints(List<Complaint> complaints) {
    if (_statusFilter == 'all') return complaints;
    if (_statusFilter == 'under_review') {
      return complaints.where((c) {
        final s = c.status.toLowerCase();
        return s == 'submitted' || s == 'under_review' || s == 'open';
      }).toList();
    }
    return complaints.where((c) => c.status.toLowerCase() == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Complaints'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh complaints',
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: _openNewComplaint,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('File Complaint'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE33434),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('New Complaint', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openNewComplaint,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Under Review', 'under_review'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Replied', 'replied'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Resolved', 'resolved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Closed', 'closed'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
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
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Could not load your complaints.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _refresh, child: const Text('Try Again')),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  final allComplaints = snapshot.data ?? [];
                  final filtered = _filterComplaints(allComplaints);

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade600),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _statusFilter == 'all'
                                    ? 'No complaints submitted'
                                    : 'No complaints in "${complaintStatusLabel(_statusFilter)}"',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'If you ever face an issue with a service or worker, submit a complaint here and our team will resolve it.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, height: 1.35),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE33434),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('File a Complaint'),
                                onPressed: _openNewComplaint,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildComplaintCard(filtered[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: const Color(0xFFFFD6D2),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    final s = complaint.status.toLowerCase();
    final isResolvedOrClosed = s == 'resolved' || s == 'closed';
    final hasReply = complaint.adminNote.trim().isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Complaint ID & Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.report_problem, size: 16, color: Color(0xFFE33434)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Complaint #${complaint.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF161A1D)),
                    ),
                  ],
                ),
                ComplaintStatusChip(status: complaint.status),
              ],
            ),
            const SizedBox(height: 10),

            // Service / Job information
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.home_repair_service_outlined, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Service: ${complaint.bookingSummary}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Date / Time
            if (complaint.createdAt != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Submitted: ${DateFormat("dd MMM yyyy, hh:mm a").format(complaint.createdAt!)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // Complaint Description
            const Text(
              'Your Complaint:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                complaint.description,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),

            // Admin Reply / Resolution Section
            if (hasReply) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isResolvedOrClosed ? Colors.green.shade50 : const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isResolvedOrClosed ? Colors.green.shade200 : Colors.purple.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isResolvedOrClosed ? Icons.verified : Icons.reply_rounded,
                          color: isResolvedOrClosed ? Colors.green.shade700 : Colors.purple.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isResolvedOrClosed ? 'SmartFix Resolution Reply' : 'Admin Reply',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isResolvedOrClosed ? Colors.green.shade800 : Colors.purple.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (complaint.resolvedAt != null)
                          Text(
                            DateFormat("dd MMM, hh:mm a").format(complaint.resolvedAt!),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complaint.adminNote,
                      style: const TextStyle(fontSize: 13.5, height: 1.35, color: Color(0xFF161A1D)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    'Our support team is reviewing your complaint. Check back for reply.',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
