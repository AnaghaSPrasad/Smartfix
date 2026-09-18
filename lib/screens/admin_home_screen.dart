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
  bool _showVerified = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _workersFuture = _api.getWorkers(verified: _showVerified);

  Future<void> _refresh() async {
    _load();
    setState(() {});
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.pending_actions),
                label: Text('Pending verification'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.verified_user),
                label: Text('Verified'),
              ),
            ],
            selected: {_showVerified},
            onSelectionChanged: (selection) {
              setState(() {
                _showVerified = selection.first;
                _load();
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
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
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(_showVerified
                        ? 'No verified workers yet.'
                        : 'No workers are waiting for verification.'),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final w = workers[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: w.isVerified ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(
                      w.isVerified ? Icons.verified : Icons.hourglass_top,
                      color: w.isVerified ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
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
          ),
        ),
      ],
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
    _load();
    setState(() {});
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
    _load();
    setState(() {});
    await _complaintsFuture;
  }

  Future<void> _resolve(Complaint c) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Complaint'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Resolution note (optional)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Resolved')),
        ],
      ),
    );
    if (confirmed == true) {
      final adminNote = noteController.text.trim();
      if (adminNote.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please provide a solution before resolving the complaint.')),
          );
        }
        return;
      }
      try {
        await _api.resolveComplaint(c.id, adminNote);
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(c.bookingSummary, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Chip(
                            label: Text(c.status == 'open' ? 'Open' : 'Resolved'),
                            backgroundColor: c.status == 'open' ? Colors.red.shade100 : Colors.green.shade100,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text('From: ${c.customerName}', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(c.description),
                      if (c.status == 'resolved' && c.adminNote.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Admin note: ${c.adminNote}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                      if (c.status == 'open') ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => _resolve(c),
                            child: const Text('Resolve'),
                          ),
                        ),
                      ],
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
