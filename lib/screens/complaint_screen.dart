import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_widgets.dart';

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

    try {
      final fullDescription = '[$_complaintCategory] ${_descriptionController.text.trim()}';
      await _api.fileComplaint(_selectedBooking!.id, fullDescription);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Complaint submitted successfully. Our team will review and reply soon.'),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = 'Failed to submit complaint: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('File a Complaint'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              AppBanner.info(
                'Your satisfaction is our priority. Please tell us about the issue and our support admin will investigate and respond promptly.',
              ),
              const SizedBox(height: 18),

              // Service / Booking Selector
              const Text(
                'Select Relevant Service / Booking *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              if (_loadingBookings)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (widget.booking != null)
                // Pre-selected booking card
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.booking!.serviceName} (Booking #${widget.booking!.id})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Address: ${widget.booking!.address}',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_myBookings.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'No bookings found. You need at least one service booking to file a complaint.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<Booking>(
                  initialValue: _selectedBooking,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.receipt_long_outlined, size: 20),
                  ),
                  isExpanded: true,
                  items: _myBookings.map((b) {
                    return DropdownMenuItem<Booking>(
                      value: b,
                      child: Text(
                        '#${b.id} - ${b.serviceName} (${b.status})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    );
                  }).toList(),
                  onChanged: (b) => setState(() => _selectedBooking = b),
                  validator: (b) => b == null ? 'Please choose a booking' : null,
                ),

              const SizedBox(height: 18),

              // Issue Category Selector
              const Text(
                'Issue Category *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _complaintCategory,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(c, style: const TextStyle(fontSize: 13.5)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _complaintCategory = val);
                },
              ),

              const SizedBox(height: 18),

              // Complaint Description
              const Text(
                'Complaint Description *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Please describe the problem in detail (what happened, date, impact, etc.)...',
                  alignLabelWithHint: true,
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
                const SizedBox(height: 14),
                AppBanner.error(_error!),
              ],

              const SizedBox(height: 24),

              // Submit Button
              AppButton(
                text: 'Submit Complaint',
                icon: Icons.send_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting || (_selectedBooking == null && _myBookings.isEmpty && widget.booking == null)
                    ? null
                    : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
