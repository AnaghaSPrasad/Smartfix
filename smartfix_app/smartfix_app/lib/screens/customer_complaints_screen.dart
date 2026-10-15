import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/complaint.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Complaints'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh complaints',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openNewComplaint,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('File Complaint'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('New Complaint', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openNewComplaint,
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
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
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Complaint>>(
                future: _complaintsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              AppBanner.error('Could not load your complaints.\n${snapshot.error}'),
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
                          child: AppEmptyState(
                            icon: Icons.check_circle_outline,
                            title: _statusFilter == 'all'
                                ? 'No complaints submitted'
                                : 'No complaints in "${complaintStatusLabel(_statusFilter)}"',
                            subtitle: 'If you ever face an issue with a service or worker, submit a complaint here and our team will resolve it.',
                            actionText: 'File a Complaint',
                            onAction: _openNewComplaint,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
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
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: AppColors.primaryLight,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    final s = complaint.status.toLowerCase();
    final isResolvedOrClosed = s == 'resolved' || s == 'closed';
    final hasReply = complaint.adminNote.trim().isNotEmpty;

    return AppCard(
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
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.report_problem, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Complaint #${complaint.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
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
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_repair_service_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Service: ${complaint.bookingSummary}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Date / Time
          if (complaint.createdAt != null)
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${DateFormat("dd MMM yyyy, hh:mm a").format(complaint.createdAt!)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),

          const SizedBox(height: 10),

          // Complaint Description
          const Text(
            'Your Complaint:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              complaint.description,
              style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.textPrimary),
            ),
          ),

          // Admin Reply / Resolution Section
          if (hasReply) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isResolvedOrClosed ? AppColors.successLight : const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isResolvedOrClosed ? const Color(0xFF86EFAC) : Colors.purple.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isResolvedOrClosed ? Icons.verified : Icons.reply_rounded,
                        color: isResolvedOrClosed ? const Color(0xFF15803D) : Colors.purple.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isResolvedOrClosed ? 'SmartFix Resolution Reply' : 'Admin Reply',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isResolvedOrClosed ? const Color(0xFF15803D) : Colors.purple.shade800,
                        ),
                      ),
                      const Spacer(),
                      if (complaint.resolvedAt != null)
                        Text(
                          DateFormat("dd MMM, hh:mm a").format(complaint.resolvedAt!),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    complaint.adminNote,
                    style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.hourglass_empty, size: 14, color: AppColors.warning),
                SizedBox(width: 6),
                Text(
                  'Our support team is reviewing your complaint. Check back for reply.',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
