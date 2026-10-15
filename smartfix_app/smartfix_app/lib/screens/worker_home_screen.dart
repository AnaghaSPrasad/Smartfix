import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';
import '../utils/status_style.dart';
import 'login_screen.dart';
import 'worker_tracking_screen.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Available Jobs' : 'My Jobs'),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    profile.isAvailable ? 'Available' : 'Offline',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: profile.isAvailable ? AppColors.success : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: profile.isAvailable,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
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
                                  const SnackBar(
                                    content: Text('Failed to update availability.'),
                                    backgroundColor: AppColors.error,
                                  ),
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
            tooltip: 'Log out',
            onPressed: () async {
              final confirmed = await showAppConfirmDialog(
                context: context,
                title: 'Log Out',
                message: 'Are you sure you want to log out from SmartFix?',
                confirmLabel: 'Log Out',
                isDestructive: true,
              );
              if (confirmed == true && context.mounted) {
                await auth.logout();
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
      body: Column(
        children: [
          if (!isVerified)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: AppBanner.warning(
                'Your account is pending admin verification. You can browse jobs, but you cannot accept them until an admin verifies your account.',
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
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'My Jobs'),
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
    setState(_load);
    await _jobsFuture;
  }

  Future<void> _accept(Booking job) async {
    try {
      await _api.acceptJob(job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Accepted job: ${job.serviceName}'),
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
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
      child: FutureBuilder<List<Booking>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AppBanner.error('Could not load jobs.\n${snapshot.error}'),
                ),
              ],
            );
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60.0),
                  child: AppEmptyState(
                    icon: Icons.work_off_outlined,
                    title: 'No open jobs available',
                    subtitle: 'New requests in your category will appear here in real time.',
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job.serviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                        ),
                        if (job.requestType == 'urgent')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, size: 14, color: AppColors.primary),
                                SizedBox(width: 2),
                                Text('Urgent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Customer: ${job.customerName ?? '-'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Address: ${job.address}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    if (job.scheduledDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Scheduled: ${job.scheduledDate!.toLocal()}'.split('.')[0],
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (job.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Notes: ${job.notes}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                    ],
                    const Divider(height: 22),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        onPressed: widget.isVerified ? () => _accept(job) : null,
                        label: const Text('Accept Job'),
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
    setState(_load);
    await _jobsFuture;
  }

  Future<void> _shareLocation(Booking job, {bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS to share your live location.')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        await _api.updateWorkerLocation(job.id, pos.latitude, pos.longitude);
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Live location transmitted to customer!'),
            ),
          );
        }
        _refresh();
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Could not get GPS: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(Booking job, String newStatus) async {
    try {
      await _api.updateJobStatus(job.id, newStatus);
      if (newStatus == 'on_the_way' || newStatus == 'arrived') {
        _shareLocation(job, silent: true);
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
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
      child: FutureBuilder<List<Booking>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AppBanner.error('Could not load jobs.\n${snapshot.error}'),
                ),
              ],
            );
          }
          final jobs = snapshot.data ?? [];
          if (jobs.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60.0),
                  child: AppEmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No assigned jobs yet',
                    subtitle: 'Accept an open job from the first tab or wait for an auto-assigned request.',
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job.serviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          ),
                        ),
                        StatusChip(status: job.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (job.requestType == 'urgent')
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Urgent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    Text('Customer: ${job.customerName ?? '-'}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 3),
                    Text('Address: ${job.address}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    if (job.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Notes: ${job.notes}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                    ],
                    const Divider(height: 22),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.navigation, size: 15),
                          label: const Text('Map / Track'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => WorkerTrackingScreen(booking: job)),
                            );
                          },
                        ),
                        if (job.status == 'assigned') ...[
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _updateStatus(job, 'accepted'),
                            child: const Text('Accept Job'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.directions_bike, size: 15),
                            onPressed: () => _updateStatus(job, 'on_the_way'),
                            label: const Text('On The Way'),
                          ),
                        ],
                        if (job.status == 'accepted')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.directions_bike, size: 15),
                            onPressed: () => _updateStatus(job, 'on_the_way'),
                            label: const Text('On The Way'),
                          ),
                        if (job.status == 'on_the_way')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE65100),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.pin_drop, size: 15),
                            onPressed: () => _updateStatus(job, 'arrived'),
                            label: const Text('Mark Arrived'),
                          ),
                        if (job.status == 'arrived')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.play_arrow, size: 15),
                            onPressed: () => _updateStatus(job, 'in_progress'),
                            label: const Text('Start Work'),
                          ),
                        if (job.status == 'in_progress')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.done_all, size: 15),
                            onPressed: () => _updateStatus(job, 'completed'),
                            label: const Text('Mark Complete'),
                          ),
                        if (job.status != 'completed' && job.status != 'cancelled')
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _updateStatus(job, 'cancelled'),
                            child: const Text('Cancel'),
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
    );
  }
}
