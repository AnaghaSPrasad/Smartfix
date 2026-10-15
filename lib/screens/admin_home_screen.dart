import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../models/complaint.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';
import '../utils/status_style.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tabIndex = 0;
  static const _titles = ['Verify Workers', 'All Bookings', 'Complaints'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              final confirmed = await showAppConfirmDialog(
                context: context,
                title: 'Log Out',
                message: 'Are you sure you want to log out of the Admin portal?',
                confirmLabel: 'Log Out',
                isDestructive: true,
              );
              if (confirmed == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _VerifyWorkersTab(),
          _AllBookingsTab(),
          _ComplaintsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: 'Workers'),
          NavigationDestination(icon: Icon(Icons.list_alt), selectedIcon: Icon(Icons.list_alt), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.report_problem_outlined), selectedIcon: Icon(Icons.report_problem), label: 'Complaints'),
        ],
      ),
    );
  }
}

// ---------------- Verify Workers ----------------

class _VerifyWorkersTab extends StatefulWidget {
  const _VerifyWorkersTab();

  @override
  State<_VerifyWorkersTab> createState() => _VerifyWorkersTabState();
}

class _VerifyWorkersTabState extends State<_VerifyWorkersTab> {
  final ApiService _api = ApiService();
  late Future<List<AppUser>> _workersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _workersFuture = _api.getWorkers();

  Future<void> _refresh() async {
    setState(_load);
    await _workersFuture;
  }

  Future<void> _setVerified(AppUser worker, bool verify) async {
    try {
      await _api.verifyWorker(worker.id, verify);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<AppUser>>(
        future: _workersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppBanner.error('${snapshot.error}'),
                ),
              ],
            );
          }
          final workers = snapshot.data ?? [];
          if (workers.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No workers registered yet',
                    subtitle: 'Registered service providers will show up here for verification.',
                  ),
                ),
              ],
            );
          }
          // Pending workers first.
          final sorted = [...workers]..sort((a, b) => (a.isVerified ? 1 : 0) - (b.isVerified ? 1 : 0));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final w = sorted[index];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: w.isVerified ? AppColors.successLight : AppColors.warningLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        w.isVerified ? Icons.verified : Icons.hourglass_top,
                        color: w.isVerified ? AppColors.success : AppColors.warning,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                w.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: w.isVerified ? AppColors.successLight : AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  w.isVerified ? 'Verified' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: w.isVerified ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${w.category ?? '-'} • ${w.email}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          if (w.phone != null && w.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${w.phone}',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    w.isVerified
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            onPressed: () => _setVerified(w, false),
                            child: const Text('Revoke', style: TextStyle(fontSize: 12)),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.success,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            ),
                            onPressed: () => _setVerified(w, true),
                            child: const Text('Verify', style: TextStyle(fontSize: 12)),
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- All Bookings ----------------

class _AllBookingsTab extends StatefulWidget {
  const _AllBookingsTab();

  @override
  State<_AllBookingsTab> createState() => _AllBookingsTabState();
}

class _AllBookingsTabState extends State<_AllBookingsTab> {
  final ApiService _api = ApiService();
  late Future<List<Booking>> _bookingsFuture;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _bookingsFuture = _api.getAllBookings(status: _statusFilter);

  Future<void> _refresh() async {
    setState(_load);
    await _bookingsFuture;
  }

  @override
  Widget build(BuildContext context) {
    const statuses = ['pending', 'assigned', 'in_progress', 'completed', 'cancelled'];
    return Column(
      children: [
        Container(
          color: Colors.white,
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildFilterChip('All', _statusFilter == null, () {
                setState(() {
                  _statusFilter = null;
                  _load();
                });
              }),
              ...statuses.map((s) => _buildFilterChip(statusLabel(s), _statusFilter == s, () {
                    setState(() {
                      _statusFilter = s;
                      _load();
                    });
                  })),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: FutureBuilder<List<Booking>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppBanner.error('${snapshot.error}'),
                      ),
                    ],
                  );
                }
                final bookings = snapshot.data ?? [];
                if (bookings.isEmpty) {
                  return ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: AppEmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'No bookings found',
                          subtitle: 'Bookings matching this filter will show up here.',
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  b.serviceName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                              ),
                              StatusChip(status: b.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text('Customer: ${b.customerName ?? '-'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.handyman_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text('Worker: ${b.workerName ?? 'Unassigned'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                b.requestType == 'urgent' ? Icons.bolt : Icons.schedule,
                                size: 14,
                                color: b.requestType == 'urgent' ? AppColors.primary : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                b.requestType == 'urgent' ? '⚡ Urgent Request' : 'Scheduled: ${b.scheduledDate?.toLocal().toString().split('.')[0] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: b.requestType == 'urgent' ? FontWeight.w600 : FontWeight.normal,
                                  color: b.requestType == 'urgent' ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12.5,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primaryLight,
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// ---------------- Complaints ----------------

class _ComplaintsTab extends StatefulWidget {
  const _ComplaintsTab();

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab> {
  final ApiService _api = ApiService();
  late Future<List<Complaint>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _complaintsFuture = _api.getComplaints();

  Future<void> _refresh() async {
    setState(_load);
    await _complaintsFuture;
  }

  Future<void> _resolve(Complaint c) async {
    final noteController = TextEditingController(text: c.adminNote);
    String selectedStatus = c.status == 'submitted' || c.status == 'open' || c.status == 'under_review'
        ? 'resolved'
        : c.status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Reply / Update Complaint #${c.id}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complaint Status:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: const [
                    DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                    DropdownMenuItem(value: 'replied', child: Text('Replied')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Admin Reply / Resolution Note:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter solution or reply message...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 40),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save & Send'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final adminNote = noteController.text.trim();
      if (adminNote.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Please provide a reply note before updating the complaint.'),
            ),
          );
        }
        return;
      }
      try {
        await _api.resolveComplaint(c.id, adminNote, status: selectedStatus);
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Failed: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
                  child: AppBanner.error('${snapshot.error}'),
                ),
              ],
            );
          }
          final complaints = snapshot.data ?? [];
          if (complaints.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: AppEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No complaints filed',
                    subtitle: 'All customer service requests are currently running smoothly.',
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final c = complaints[index];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Complaint #${c.id}: ${c.bookingSummary}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                          ),
                        ),
                        ComplaintStatusChip(status: c.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer: ${c.customerName}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.description,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.35),
                    ),
                    if (c.adminNote.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Admin response: ${c.adminNote}',
                          style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.reply, size: 15),
                        label: Text(c.adminNote.isEmpty ? 'Reply / Resolve' : 'Edit Reply'),
                        onPressed: () => _resolve(c),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}