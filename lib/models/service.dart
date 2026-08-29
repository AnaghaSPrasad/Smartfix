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

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image'],
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}
