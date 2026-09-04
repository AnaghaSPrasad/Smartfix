import 'package:flutter/material.dart';
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
  String? _error;

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
      body: Padding(
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
