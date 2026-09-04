import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class ComplaintScreen extends StatefulWidget {
  final Booking booking;
  const ComplaintScreen({super.key, required this.booking});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final ApiService _api = ApiService();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please describe the issue.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _api.fileComplaint(widget.booking.id, _descriptionController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint submitted. Admin will review it shortly.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Failed to submit complaint. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.booking.serviceName} • ${widget.booking.workerName ?? 'Unassigned'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What went wrong?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Complaint'),
            ),
          ],
        ),
      ),
    );
  }
}
