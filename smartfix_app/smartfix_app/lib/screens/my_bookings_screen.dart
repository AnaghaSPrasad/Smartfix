import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
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
      appBar: AppBar(
        title: const Text('My Bookings'),
        actions: [
          IconButton(
            tooltip: 'My complaints',
            icon: const Icon(Icons.support_agent),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerComplaintsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
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
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text('Could not load bookings.\n${snapshot.error}', textAlign: TextAlign.center),
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
                          padding: EdgeInsets.all(40.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'No bookings found.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
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
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFFFFD6D2),
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                StatusChip(status: b.status),
              ],
            ),
            const SizedBox(height: 8),
            // Request Type & Date
            Row(
              children: [
                Icon(
                  b.requestType == 'urgent' ? Icons.bolt : Icons.calendar_today,
                  size: 15,
                  color: b.requestType == 'urgent' ? Colors.deepOrange : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  b.requestType == 'urgent'
                      ? '⚡ Urgent Request (Auto-Assigned)'
                      : (b.scheduledDate != null
                          ? 'Scheduled: ${DateFormat('dd MMM yyyy, hh:mm a').format(b.scheduledDate!)}'
                          : 'Scheduled Request'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: b.requestType == 'urgent' ? FontWeight.w600 : FontWeight.normal,
                    color: b.requestType == 'urgent' ? Colors.deepOrange : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('📍 Address: ${b.address}', style: const TextStyle(fontSize: 13)),
            if (b.workerName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Color(0xFFE33434)),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned Worker: ${b.workerName}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF161A1D)),
                  ),
                ],
              ),
            ],
            if (b.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📝 Notes: ${b.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
            ],

            const Divider(height: 20),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (isTrackable)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE33434),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Track Worker'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => WorkerTrackingScreen(booking: b)),
                      );
                    },
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.grey.shade800,
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 16),
                  label: const Text('Report Issue'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ComplaintScreen(booking: b)),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
