import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class ComplaintScreen extends StatefulWidget {
  final Booking? booking;

  const ComplaintScreen({super.key, this.booking});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  Booking? _selectedBooking;
  List<Booking> _myBookings = [];
  bool _loadingBookings = false;
  bool _isSubmitting = false;
  String? _error;

  String _complaintCategory = 'Quality of Work';
  static const _categories = [
    'Quality of Work',
    'Worker Late or No-Show',
    'Unprofessional Behavior',
    'Billing or Overcharging',
    'Property Damage',
    'Other Issue',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      _selectedBooking = widget.booking;
    } else {
      _fetchBookings();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final list = await _api.getMyBookings();
      if (mounted) {
        setState(() {
          _myBookings = list;
          if (list.isNotEmpty) {
            _selectedBooking = list.first;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your bookings. Please check your connection.');
      }
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedBooking == null) {
      setState(() => _error = 'Please select the relevant service booking.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final fullDescription = '[$_complaintCategory] ${_descriptionController.text.trim()}';

    try {
      await _api.fileComplaint(_selectedBooking!.id, fullDescription);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully. Our team will review and reply.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = 'Failed to submit complaint. ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File a Complaint'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFCCC7)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent, color: Color(0xFFE33434), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your satisfaction is our priority. Please tell us about the issue and our support admin will investigate and respond promptly.',
                        style: TextStyle(color: Color(0xFF161A1D), fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

              // Service / Booking Selector
              const Text(
                'Select Relevant Service / Booking *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              if (_loadingBookings)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (widget.booking != null)
                // Pre-selected booking card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFFFE9E6),
                          child: Icon(Icons.handyman, color: Color(0xFFE33434)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.booking!.serviceName} (Booking #${widget.booking!.id})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Worker: ${widget.booking!.workerName ?? "Unassigned"} • Status: ${widget.booking!.status}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_myBookings.isEmpty)
                Card(
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No bookings found on your account. You can only file complaints on existing service requests.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<Booking>(
                  initialValue: _selectedBooking,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: _myBookings.map((b) {
                    final dateStr = b.scheduledDate != null
                        ? '${b.scheduledDate!.day}/${b.scheduledDate!.month}/${b.scheduledDate!.year}'
                        : (b.requestType == 'urgent' ? 'Urgent' : 'Created');
                    return DropdownMenuItem<Booking>(
                      value: b,
                      child: Text(
                        '#${b.id} ${b.serviceName} ($dateStr)',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (b) => setState(() => _selectedBooking = b),
                  validator: (v) => v == null ? 'Please select a booking' : null,
                ),

              const SizedBox(height: 18),

              // Category Selector
              const Text(
                'Type of Issue *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _complaintCategory,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _complaintCategory = v);
                },
              ),

              const SizedBox(height: 18),

              // Description Field
              const Text(
                'Complaint Description *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Please describe in detail what went wrong, what the worker did, or how the service did not meet your expectations...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE33434), width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description of the issue';
                  }
                  if (value.trim().length < 8) {
                    return 'Please provide a bit more detail (at least 8 characters)';
                  }
                  return null;
                },
              ),

              // Error banner
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE33434),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSubmitting || (_selectedBooking == null && _myBookings.isEmpty && widget.booking == null)
                      ? null
                      : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Complaint',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
