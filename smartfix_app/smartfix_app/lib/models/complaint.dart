class Complaint {
  final int id;
  final int bookingId;
  final String bookingSummary;
  final String customerName;
  final String description;
  final String status; // 'open' or 'resolved'
  final String adminNote;
  final DateTime? createdAt;

  Complaint({
    required this.id,
    required this.bookingId,
    required this.bookingSummary,
    required this.customerName,
    required this.description,
    required this.status,
    this.adminNote = '',
    this.createdAt,
  });

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: _parseInt(json['id']),
      bookingId: _parseInt(json['booking']),
      bookingSummary: json['booking_summary']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      adminNote: json['admin_note']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

