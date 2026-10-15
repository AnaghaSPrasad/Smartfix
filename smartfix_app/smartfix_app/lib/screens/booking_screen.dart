import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/service.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';

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
  String? _error;

  // Location detection state
  double? _detectedLat;
  double? _detectedLng;
  bool _isDetectingLocation = false;
  String? _locationStatusNote;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (mounted) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time?.hour ?? 10,
            time?.minute ?? 0,
          );
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _error = 'Location services (GPS) are disabled. Please enable GPS in device settings or enter address manually.';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _error = 'Location permission was denied. You can enter your service address manually.';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = 'Location permissions are permanently denied. Please enable them in app settings or enter address manually.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _detectedLat = position.latitude;
      _detectedLng = position.longitude;

      String resolvedAddress = '';
      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        );
        final res = await http.get(uri, headers: {
          'User-Agent': 'SmartFixApp/1.0 (contact@smartfix.local)',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['display_name'] != null) {
            resolvedAddress = data['display_name'].toString();
          }
        }
      } catch (_) {
        // Fall back gracefully to coordinate string
      }

      if (resolvedAddress.isEmpty) {
        resolvedAddress = 'Near GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }

      if (mounted) {
        setState(() {
          _addressController.text = resolvedAddress;
          _locationStatusNote = 'GPS detected (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}). You can edit details above.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not detect current location. Please type your address manually.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _submitBooking() async {
    if (_addressController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your service address.');
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
        customerLat: _detectedLat,
        customerLng: _detectedLng,
      );
      await _api.createBooking(booking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _requestType == 'urgent'
                        ? 'Urgent request sent! We are matching you with the nearest available worker.'
                        : 'Booking confirmed successfully!',
                  ),
                ),
              ],
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Book ${widget.service.name}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Service Summary Header Card
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.service.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.service.category,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Price',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                      Text(
                        '₹${widget.service.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Request Type',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        icon: Icon(Icons.calendar_today_outlined),
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
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Scheduled Date Picker Box
                  if (_requestType == 'scheduled') ...[
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedDate == null ? AppColors.border : AppColors.primary,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                          color: _selectedDate == null ? Colors.white : AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: _selectedDate == null ? AppColors.textSecondary : AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedDate == null
                                    ? 'Select Date & Time *'
                                    : '${_selectedDate!.toLocal()}'.split('.')[0],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.w600,
                                  color: _selectedDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Service Address Header with Current Location action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service Address *',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed: _isDetectingLocation ? null : _useCurrentLocation,
                        icon: _isDetectingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.my_location, size: 16),
                        label: Text(
                          _isDetectingLocation ? 'Locating...' : 'Use Current Location',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'House/Flat No., Street, Landmark, Area',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      suffixIcon: _addressController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _addressController.clear();
                                  _detectedLat = null;
                                  _detectedLng = null;
                                  _locationStatusNote = null;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                  if (_locationStatusNote != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _locationStatusNote!,
                            style: const TextStyle(fontSize: 12, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Notes Field
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes for the worker (optional)',
                      hintText: 'e.g. Please bring extra piping, gate bell is broken',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.note_alt_outlined, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error Display
                  if (_error != null) ...[
                    AppBanner.error(_error!),
                    const SizedBox(height: 16),
                  ],

                  // Submit Button
                  AppButton(
                    text: _requestType == 'urgent' ? 'Send Urgent Request' : 'Confirm Booking',
                    isLoading: _isSubmitting,
                    icon: _requestType == 'urgent' ? Icons.bolt : Icons.check_circle_outline,
                    onPressed: _submitBooking,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
