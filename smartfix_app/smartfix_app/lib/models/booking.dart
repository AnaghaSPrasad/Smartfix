class Booking {
  final int id;
  final int serviceId;
  final String serviceName;
  final String category;
  final String requestType; // 'urgent' or 'scheduled'
  final DateTime? scheduledDate;
  final String status; // pending, assigned, in_progress, completed, cancelled
  final String address;
  final String notes;
  final double? customerLat;
  final double? customerLng;
  final double? workerLat;
  final double? workerLng;
  final DateTime? workerLocationUpdatedAt;
  final String? customerName;
  final int? workerId;
  final String? workerName;
  final DateTime? createdAt;

  Booking({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    this.category = '',
    required this.requestType,
    this.scheduledDate,
    required this.status,
    required this.address,
    this.notes = '',
    this.customerLat,
    this.customerLng,
    this.workerLat,
    this.workerLng,
    this.workerLocationUpdatedAt,
    this.customerName,
    this.workerId,
    this.workerName,
    this.createdAt,
  });

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: _parseInt(json['id']),
      serviceId: _parseInt(json['service']),
      serviceName: json['service_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      requestType: json['request_type']?.toString() ?? 'scheduled',
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.tryParse(json['scheduled_date'].toString())
          : null,
      status: json['status']?.toString() ?? 'pending',
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      customerLat: _parseDouble(json['customer_lat'] ?? json['latitude']),
      customerLng: _parseDouble(json['customer_lng'] ?? json['longitude']),
      workerLat: _parseDouble(json['worker_lat'] ?? json['worker_latitude']),
      workerLng: _parseDouble(json['worker_lng'] ?? json['worker_longitude']),
      workerLocationUpdatedAt: json['worker_location_updated_at'] != null
          ? DateTime.tryParse(json['worker_location_updated_at'].toString())
          : null,
      customerName: json['customer_name']?.toString(),
      workerId: json['worker'] != null ? _parseInt(json['worker']) : null,
      workerName: json['worker_name']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service': serviceId,
      'request_type': requestType,
      if (scheduledDate != null) 'scheduled_date': scheduledDate!.toIso8601String(),
      'address': address,
      'notes': notes,
      if (customerLat != null) 'customer_lat': customerLat,
      if (customerLng != null) 'customer_lng': customerLng,
    };
  }
}


