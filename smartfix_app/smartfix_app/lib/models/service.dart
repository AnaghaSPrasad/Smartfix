class ServiceItem {
  final int id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String? imageUrl;
  final double? rating;

  ServiceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    this.imageUrl,
    this.rating,
  });

  static double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static int _parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: _parseDouble(json['price']),
      imageUrl: json['image']?.toString(),
      rating: json['rating'] != null ? _parseDouble(json['rating']) : null,
    );
  }
}


