import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/status_style.dart';
import 'login_screen.dart';



class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int _tabIndex = 0;
  final ApiService _api = ApiService();
  bool _updatingAvailability = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final isVerified = profile?.isVerified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Available Jobs' : 'My Jobs'),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(profile.isAvailable ? 'Available' : 'Offline', style: const TextStyle(fontSize: 12)),
                  Switch(
                    value: profile.isAvailable,
                    onChanged: _updatingAvailability
                        ? null
                        : (v) async {
                            setState(() => _updatingAvailability = true);
                            try {
                              await _api.updateAvailability(v);
                              await auth.refreshProfile();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to update availability.')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _updatingAvailability = false);
                            }
                          },
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
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
      body: Column(
        children: [
          if (!isVerified)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Your account is pending admin verification. You can browse jobs, but you '
                'cannot accept them until an admin verifies your account.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _OpenJobsTab(isVerified: isVerified),
                const _MyJobsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Open Jobs'),
          NavigationDestination(icon: Icon(Icons.work), label: 'My Jobs'),
        ],
      ),
    );
  }
}

class _OpenJobsTab extends StatefulWidget {
  final bool isVerified;
  const _OpenJobsTab({required this.isVerified});

  @override
  State<_OpenJobsTab> createState() => _OpenJobsTabState();
}

class _OpenJobsTabState extends State<_OpenJobsTab> {
  final ApiService _api = ApiService();
  late Future<List<Booking>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _jobsFuture = _api.getOpenJobs();

  Future<void> _refresh() async {
    _load();
    setState(() {});
    await _jobsFuture;
  }

  Future<void> _accept(Booking job) async {
    try {
      await _api.acceptJob(job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accepted: ${job.serviceName}')),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Booking>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Could not load jobs.\n${snapshot.error}', textAlign: TextAlign.center),
                ),
              ],
            );
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No open jobs in your category right now.')),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Customer: ${job.customerName ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text('Address: ${job.address}', style: const TextStyle(fontSize: 13)),
                      if (job.scheduledDate != null)
                        Text(
                          'Scheduled: ${job.scheduledDate!.toLocal()}'.split('.')[0],
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (job.notes.isNotEmpty)
                        Text('Notes: ${job.notes}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: widget.isVerified ? () => _accept(job) : null,
                          child: const Text('Accept Job'),
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

class _MyJobsTab extends StatefulWidget {
  const _MyJobsTab();

  @override
  State<_MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends State<_MyJobsTab> {
  final ApiService _api = ApiService();
  late Future<List<Booking>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _jobsFuture = _api.getMyJobs();

  Future<void> _refresh() async {
    _load();
    setState(() {});
    await _jobsFuture;
  }

  Future<void> _updateStatus(Booking job, String newStatus) async {
    try {
      await _api.updateJobStatus(job.id, newStatus);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Booking>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Could not load jobs.\n${snapshot.error}', textAlign: TextAlign.center),
                ),
              ],
            );
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No jobs assigned yet. Accept an open job or wait for an urgent match.')),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
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
                          Expanded(
                            child: Text(job.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          StatusChip(status: job.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (job.requestType == 'urgent')
                        const Row(
                          children: [
                            Icon(Icons.bolt, size: 14, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Urgent', style: TextStyle(fontSize: 12, color: Colors.red)),
                          ],
                        ),
                      Text('Customer: ${job.customerName ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text('Address: ${job.address}', style: const TextStyle(fontSize: 13)),
                      if (job.notes.isNotEmpty)
                        Text('Notes: ${job.notes}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (job.status == 'assigned')
                              ElevatedButton(
                                onPressed: () => _updateStatus(job, 'in_progress'),
                                child: const Text('Start Job'),
                              ),
                            if (job.status == 'in_progress')
                              ElevatedButton(
                                onPressed: () => _updateStatus(job, 'completed'),
                                child: const Text('Mark Complete'),
                              ),
                            if (job.status == 'assigned' || job.status == 'in_progress')
                              OutlinedButton(
                                onPressed: () => _updateStatus(job, 'cancelled'),
                                child: const Text('Cancel'),
                              ),
                          ],
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
