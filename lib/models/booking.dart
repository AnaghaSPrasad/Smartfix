class Booking {
  final int id;
  final int serviceId;
  final String serviceName;
  final DateTime scheduledDate;
  final String status; // pending, confirmed, completed, cancelled
  final String address;

  Booking({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledDate,
    required this.status,
    required this.address,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      serviceId: json['service'],
      serviceName: json['service_name'] ?? '',
      scheduledDate: DateTime.parse(json['scheduled_date']),
      status: json['status'] ?? 'pending',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service': serviceId,
      'scheduled_date': scheduledDate.toIso8601String(),
      'address': address,
    };
  }
}
