class AppUser {
  final int id;
  final int? userId;
  final String username;
  final String email;
  final String? phone;
  final String role; // 'customer', 'worker', or 'admin'
  final String? category; // workers only
  final bool isVerified;
  final bool isAvailable;
  final DateTime? dateJoined;

  AppUser({
    required this.id,
    this.userId,
    required this.username,
    required this.email,
    this.phone,
    required this.role,
    this.category,
    this.isVerified = true,
    this.isAvailable = true,
    this.dateJoined,
  });

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _parseInt(json['id']),
      userId: json['user_id'] != null ? _parseInt(json['user_id']) : null,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? (json['category'] != null ? 'worker' : 'customer'),
      category: json['category']?.toString(),
      isVerified: json['is_verified'] == true || json['is_verified']?.toString() == 'true',
      isAvailable: json['is_available'] == null ? true : (json['is_available'] == true || json['is_available']?.toString() == 'true'),
      dateJoined: json['date_joined'] != null ? DateTime.tryParse(json['date_joined'].toString()) : null,
    );
  }
}

