import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../utils/status_style.dart';
import 'complaint_screen.dart';
import 'customer_complaints_screen.dart';

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
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
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
                    bookings = bookings.where((b) => b.status == 'pending' || b.status == 'assigned' || b.status == 'in_progress').toList();
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
      selectedColor: Colors.blueAccent.shade100,
    );
  }

  Widget _buildBookingCard(Booking b) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 6),
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
              Text('👤 Assigned Worker: ${b.workerName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blueAccent)),
            ],
            if (b.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📝 Notes: ${b.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
            ],

            // Complaint / Report Button on completed jobs
            if (b.status == 'completed') ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.report_problem_outlined, size: 16),
                  label: const Text('Report Issue / File Complaint'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ComplaintScreen(booking: b)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
