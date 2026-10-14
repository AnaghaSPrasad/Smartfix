import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../models/complaint.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
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
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
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
          NavigationDestination(icon: Icon(Icons.verified_user), label: 'Workers'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.report_problem), label: 'Complaints'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<AppUser>>(
        future: _workersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'))],
            );
          }
          final workers = snapshot.data ?? [];
          if (workers.isEmpty) {
            return ListView(
              children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No workers have registered yet.')))],
            );
          }
          // Pending workers first.
          final sorted = [...workers]..sort((a, b) => (a.isVerified ? 1 : 0) - (b.isVerified ? 1 : 0));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final w = sorted[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    w.isVerified ? Icons.verified : Icons.hourglass_top,
                    color: w.isVerified ? Colors.green : Colors.orange,
                  ),
                  title: Text(w.username),
                  subtitle: Text('${w.category ?? '-'} • ${w.email}\n${w.phone ?? ''}'),
                  isThreeLine: true,
                  trailing: w.isVerified
                      ? OutlinedButton(
                          onPressed: () => _setVerified(w, false),
                          child: const Text('Revoke'),
                        )
                      : ElevatedButton(
                          onPressed: () => _setVerified(w, true),
                          child: const Text('Verify'),
                        ),
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
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() {
                    _statusFilter = null;
                    _load();
                  }),
                ),
              ),
              ...statuses.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(statusLabel(s)),
                      selected: _statusFilter == s,
                      onSelected: (_) => setState(() {
                        _statusFilter = s;
                        _load();
                      }),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<Booking>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ListView(
                    children: [Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'))],
                  );
                }
                final bookings = snapshot.data ?? [];
                if (bookings.isEmpty) {
                  return ListView(
                    children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No bookings found.')))],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                StatusChip(status: b.status),
                              ],
                            ),
                            Text('Customer: ${b.customerName ?? '-'}', style: const TextStyle(fontSize: 13)),
                            Text('Worker: ${b.workerName ?? 'Unassigned'}', style: const TextStyle(fontSize: 13)),
                            Text(
                              b.requestType == 'urgent' ? 'Urgent' : 'Scheduled: ${b.scheduledDate?.toLocal().toString().split('.')[0] ?? '-'}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
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
          title: Text('Reply / Update Complaint #${c.id}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complaint Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
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
                const Text('Admin Reply / Resolution Note:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Enter solution or reply message...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE33434), foregroundColor: Colors.white),
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
            const SnackBar(content: Text('Please provide a reply note before updating the complaint.')),
          );
        }
        return;
      }
      try {
        await _api.resolveComplaint(c.id, adminNote, status: selectedStatus);
        _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Complaint>>(
        future: _complaintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'))],
            );
          }
          final complaints = snapshot.data ?? [];
          if (complaints.isEmpty) {
            return ListView(
              children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No complaints filed.')))],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final c = complaints[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          ComplaintStatusChip(status: c.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Customer: ${c.customerName}', style: const TextStyle(fontSize: 13, color: Colors.blueAccent)),
                      const SizedBox(height: 6),
                      Text(c.description, style: const TextStyle(fontSize: 13)),
                      if (c.adminNote.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Admin response: ${c.adminNote}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.reply, size: 16),
                          label: Text(c.adminNote.isEmpty ? 'Reply / Resolve' : 'Edit Reply'),
                          onPressed: () => _resolve(c),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}