import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/service.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class BookingScreen extends StatefulWidget {
  final ServiceItem service;

  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ApiService _api = ApiService();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  String _requestType = 'scheduled'; // 'urgent' or 'scheduled'
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  bool _isLocating = false;
  String? _error;
  LatLng? _selectedLocation;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled. You can enter the address manually.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted. You can enter the address manually.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);
      var address = 'Location: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      try {
        final response = await http.get(
          Uri.https('nominatim.openstreetmap.org', '/reverse', {
            'format': 'jsonv2',
            'lat': position.latitude.toString(),
            'lon': position.longitude.toString(),
            'zoom': '18',
            'addressdetails': '1',
          }),
          headers: {'User-Agent': 'SmartFix customer app'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          address = data['display_name']?.toString() ?? address;
        }
      } catch (_) {
        // Coordinates remain useful if reverse geocoding is temporarily unavailable.
      }

      if (!mounted) return;
      setState(() {
        _selectedLocation = location;
        _addressController.text = address;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );
      if (mounted) {
        setState(() {
          _selectedDate = DateTime(
            picked.year, picked.month, picked.day,
            time?.hour ?? 10, time?.minute ?? 0,
          );
        });
      }
    }
  }


  Future<void> _submitBooking() async {
    if (_addressController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your address.');
      return;
    }
    if (_requestType == 'scheduled' && _selectedDate == null) {
      setState(() => _error = 'Please pick a date and time for your scheduled request.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final booking = Booking(
        id: 0,
        serviceId: widget.service.id,
        serviceName: widget.service.name,
        requestType: _requestType,
        scheduledDate: _requestType == 'scheduled' ? _selectedDate : null,
        status: 'pending',
        address: _addressController.text.trim(),
        notes: _notesController.text.trim(),
      );
      await _api.createBooking(booking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _requestType == 'urgent'
                  ? 'Urgent request sent! We are matching you with the nearest available worker.'
                  : 'Booking confirmed!',
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _error = 'Booking failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.service.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Request type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'urgent',
                  label: Text('Urgent'),
                  icon: Icon(Icons.bolt),
                ),
                ButtonSegment(
                  value: 'scheduled',
                  label: Text('Scheduled'),
                  icon: Icon(Icons.calendar_today),
                ),
              ],
              selected: {_requestType},
              onSelectionChanged: (selection) {
                setState(() => _requestType = selection.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _requestType == 'urgent'
                  ? 'We will immediately assign the nearest available verified worker.'
                  : 'Pick a convenient date and time; a worker will accept your request.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_requestType == 'scheduled')
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedDate == null
                      ? 'Select a date & time'
                      : '${_selectedDate!.toLocal()}'.split('.')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Service Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLocating ? null : _useCurrentLocation,
              icon: _isLocating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLocating ? 'Finding your location...' : 'Use my current location'),
            ),
            if (_selectedLocation != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedLocation!,
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.smartfix.smartfix_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 48,
                            height: 48,
                            child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Location selected. You can edit the address above if needed.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes for the worker (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitBooking,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_requestType == 'urgent' ? 'Send Urgent Request' : 'Confirm Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
