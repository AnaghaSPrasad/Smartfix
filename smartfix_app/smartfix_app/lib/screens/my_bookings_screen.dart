import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';
import '../utils/status_style.dart';
import 'complaint_screen.dart';
import 'customer_complaints_screen.dart';
import 'worker_tracking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ApiService _api = ApiService();
  late Future<List<Booking>> _bookingsFuture;
  String _filter = 'all'; // 'all', 'active', 'completed'

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bookingsFuture = _api.getMyBookings();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _bookingsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            tooltip: 'My complaints',
            icon: const Icon(Icons.support_agent, color: AppColors.primary),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerComplaintsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
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
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: AppBanner.error('Could not load bookings.\n${snapshot.error}'),
                        ),
                      ],
                    );
                  }
                  var bookings = snapshot.data ?? [];

                  if (_filter == 'active') {
                    bookings = bookings.where((b) =>
                        b.status == 'pending' ||
                        b.status == 'assigned' ||
                        b.status == 'accepted' ||
                        b.status == 'on_the_way' ||
                        b.status == 'arrived' ||
                        b.status == 'in_progress').toList();
                  } else if (_filter == 'completed') {
                    bookings = bookings.where((b) => b.status == 'completed').toList();
                  }

                  if (bookings.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 60.0),
                          child: AppEmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'No bookings found',
                            subtitle: 'Your requested and past bookings will appear here.',
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
                      return _buildBookingCard(b);
                    },
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
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primaryLight,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildBookingCard(Booking b) {
    final isTrackable = b.workerName != null ||
        b.status == 'assigned' ||
        b.status == 'accepted' ||
        b.status == 'on_the_way' ||
        b.status == 'arrived' ||
        b.status == 'in_progress' ||
        b.status == 'completed';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Service Name & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  b.serviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              StatusChip(status: b.status),
            ],
          ),
          const SizedBox(height: 10),
          // Request Type & Date
          Row(
            children: [
              Icon(
                b.requestType == 'urgent' ? Icons.bolt : Icons.calendar_today_outlined,
                size: 15,
                color: b.requestType == 'urgent' ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                b.requestType == 'urgent'
                    ? '⚡ Urgent Request (Auto-Assigned)'
                    : (b.scheduledDate != null
                        ? 'Scheduled: ${DateFormat('dd MMM yyyy, hh:mm a').format(b.scheduledDate!)}'
                        : 'Scheduled Request'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: b.requestType == 'urgent' ? FontWeight.w600 : FontWeight.normal,
                  color: b.requestType == 'urgent' ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  b.address,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          if (b.workerName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person, size: 15, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Assigned Worker: ${b.workerName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          if (b.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${b.notes}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],

          const Divider(height: 22),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.textSecondary,
                ),
                icon: const Icon(Icons.report_problem_outlined, size: 16),
                label: const Text('Report Issue'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ComplaintScreen(booking: b)),
                  );
                },
              ),
              if (isTrackable) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.navigation, size: 15),
                  label: const Text('Track Worker', style: TextStyle(fontSize: 13)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => WorkerTrackingScreen(booking: b)),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
