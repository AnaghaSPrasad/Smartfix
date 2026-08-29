class AppUser {
  final int id;
  final String username;
  final String email;
  final String? phone;
  final String? role; // 'customer' or 'provider'

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'],
    );
  }
}
