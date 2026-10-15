import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../utils/status_style.dart';
import 'complaint_screen.dart';

class WorkerTrackingScreen extends StatefulWidget {
  final Booking booking;

  const WorkerTrackingScreen({super.key, required this.booking});

  @override
  State<WorkerTrackingScreen> createState() => _WorkerTrackingScreenState();
}

class _WorkerTrackingScreenState extends State<WorkerTrackingScreen> {
  final ApiService _api = ApiService();
  late Booking _booking;
  bool _isLoading = false;
  Timer? _pollingTimer;

  // Location variables
  LatLng? _customerLocation;
  LatLng? _workerLocation;
  String _locationNote = '';
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _setupLocations();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 8 seconds for live updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshBooking(silent: true);
    });
  }

  Future<void> _refreshBooking({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final updated = await _api.getBooking(_booking.id);
      if (mounted) {
        setState(() {
          _booking = updated;
          _updateWorkerLocationFromStatus();
        });
      }
    } catch (_) {
      // Keep displaying current booking on network error
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setupLocations() async {
    // 1. Try to parse coordinates from booking address (e.g. "Location: 12.345, 67.890")
    LatLng? parsedLoc = _tryParseCoordsFromAddress(_booking.address);

    if (parsedLoc != null) {
      _customerLocation = parsedLoc;
    } else {
      // 2. Try getting user current position gracefully
      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 5),
            );
            parsedLoc = LatLng(pos.latitude, pos.longitude);
          } else {
            _locationNote = 'Location permission not granted. Showing approximate area.';
          }
        } else {
          _locationNote = 'GPS is disabled on device. Using service area.';
        }
      } catch (_) {
        _locationNote = 'Location unavailable. Showing approximate area.';
      }

      // Default fallback coordinates (city center fallback: Bangalore/general default)
      _customerLocation = parsedLoc ?? const LatLng(12.9716, 77.5946);
    }

    _updateWorkerLocationFromStatus();
    if (mounted) setState(() {});
  }

  LatLng? _tryParseCoordsFromAddress(String address) {
    try {
      final regex = RegExp(r'(-?\d+\.\d+),\s*(-?\d+\.\d+)');
      final match = regex.firstMatch(address);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (_) {}
    return null;
  }

  void _updateWorkerLocationFromStatus() {
    if (_customerLocation == null) return;

    final status = _booking.status.toLowerCase();
    final cLat = _customerLocation!.latitude;
    final cLng = _customerLocation!.longitude;

    switch (status) {
      case 'on_the_way':
        // Worker heading towards customer (~700 meters away)
        _workerLocation = LatLng(cLat + 0.0055, cLng + 0.0042);
        break;
      case 'arrived':
      case 'in_progress':
      case 'completed':
        // Worker reached customer destination
        _workerLocation = LatLng(cLat + 0.0001, cLng + 0.0001);
        break;
      case 'assigned':
      case 'accepted':
      default:
        // Worker at service hub / preparing (~1.8 km away)
        _workerLocation = LatLng(cLat + 0.0145, cLng + 0.0110);
        break;
    }
  }

  int _getCurrentStepIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'assigned':
        return 1;
      case 'accepted':
        return 2;
      case 'on_the_way':
        return 3;
      case 'arrived':
        return 4;
      case 'in_progress':
        return 5;
      case 'completed':
        return 6;
      case 'cancelled':
        return -1;
      default:
        return 1;
    }
  }

  String _getEtaText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Matching with the best worker';
      case 'assigned':
        return 'Worker assigned, waiting for confirmation';
      case 'accepted':
        return 'Worker accepted, preparing tools';
      case 'on_the_way':
        return 'Arriving in approx. 12-15 mins';
      case 'arrived':
        return 'Worker has arrived at your door!';
      case 'in_progress':
        return 'Service currently underway';
      case 'completed':
        return 'Service completed successfully';
      case 'cancelled':
        return 'Request was cancelled';
      default:
        return 'In progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking.status.toLowerCase();
    final stepIndex = _getCurrentStepIndex(status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Track Worker #${_booking.id}'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: () => _refreshBooking(silent: false),
            tooltip: 'Refresh tracking',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshBooking(silent: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Status Header Banner
              _buildLiveHeaderBanner(status),

              // Interactive Map
              _buildMapSection(),

              if (_locationNote.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _locationNote,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Worker Profile & Contact Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: _buildWorkerCard(),
              ),

              // Step-by-Step Progress Timeline
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: _buildTimelineCard(stepIndex, status),
              ),

              // Booking Details Card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: _buildJobDetailsCard(),
              ),

              // Bottom Actions (Call, Complaint)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveHeaderBanner(String status) {
    final color = statusColor(status);
    final eta = _getEtaText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      statusLabel(status),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(status: status),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final custLoc = _customerLocation ?? const LatLng(12.9716, 77.5946);
    final workLoc = _workerLocation ?? LatLng(custLoc.latitude + 0.005, custLoc.longitude + 0.004);

    return Container(
      height: 260,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: custLoc,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.smartfix.smartfix_app',
                ),
                // Route line connecting worker and customer
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [workLoc, custLoc],
                      strokeWidth: 4.0,
                      color: const Color(0xFFE33434),
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Customer Destination Marker
                    Marker(
                      point: custLoc,
                      width: 50,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF161A1D),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.home, color: Colors.white, size: 20),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF161A1D), size: 16),
                        ],
                      ),
                    ),
                    // Worker Live Marker
                    Marker(
                      point: workLoc,
                      width: 56,
                      height: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE33434),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE33434).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.directions_bike, color: Colors.white, size: 22),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFFE33434), size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Map controls overlay
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map_recenter_cust',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF161A1D),
                    onPressed: () => _mapController.move(custLoc, 15),
                    tooltip: 'Focus Destination',
                    child: const Icon(Icons.home, size: 18),
                  ),
                  const SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: 'map_recenter_worker',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFE33434),
                    onPressed: () => _mapController.move(workLoc, 15),
                    tooltip: 'Focus Worker',
                    child: const Icon(Icons.directions_bike, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard() {
    final workerName = _booking.workerName ?? 'Worker Assigned';
    final category = _booking.category.isNotEmpty ? _booking.category : 'Service Specialist';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFFFE9E6),
              child: Icon(Icons.person, size: 36, color: Color(0xFFE33434)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          workerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Colors.blue, size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 15),
                      const SizedBox(width: 4),
                      Text('4.9 (Verified Pro)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _showContactDialog(workerName);
              },
              icon: const Icon(Icons.phone),
              tooltip: 'Contact Worker',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(int currentStep, String status) {
    final steps = [
      {'title': 'Booking Created', 'desc': 'Service request registered'},
      {'title': 'Worker Assigned', 'desc': 'Professional assigned to job'},
      {'title': 'Worker Accepted', 'desc': 'Worker confirmed the job'},
      {'title': 'On The Way', 'desc': 'Heading to your address'},
      {'title': 'Arrived', 'desc': 'Reached service location'},
      {'title': 'Work Started', 'desc': 'Service is being performed'},
      {'title': 'Work Completed', 'desc': 'Service completed successfully'},
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFFE33434), size: 20),
                SizedBox(width: 8),
                Text(
                  'Service Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(steps.length, (index) {
              final isDone = currentStep >= index;
              final isCurrent = currentStep == index;
              final isLast = index == steps.length - 1;

              Color dotColor = Colors.grey.shade300;
              if (isDone) dotColor = Colors.green;
              if (isCurrent) dotColor = const Color(0xFFE33434);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone && !isCurrent ? Icons.check : (isCurrent ? Icons.play_arrow : Icons.circle),
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 32,
                          color: isDone && currentStep > index ? Colors.green : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[index]['title']!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent
                                  ? const Color(0xFFE33434)
                                  : (isDone ? const Color(0xFF161A1D) : Colors.grey),
                            ),
                          ),
                          Text(
                            steps[index]['desc']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _booking.serviceName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _booking.address,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_booking.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Notes: ${_booking.notes}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showContactDialog(_booking.workerName ?? 'Worker'),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call Worker'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF161A1D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ComplaintScreen(booking: _booking)),
              );
            },
            icon: const Icon(Icons.report_problem_outlined, size: 18),
            label: const Text('Report Issue'),
          ),
        ),
      ],
    );
  }

  void _showContactDialog(String workerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone, color: Colors.green),
            const SizedBox(width: 8),
            Text('Contact $workerName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Direct support & worker dispatch:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.call, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text('+91 98765 43210', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Worker is on standby for this service request.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
