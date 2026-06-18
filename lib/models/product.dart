class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final String vendeurId; // ← nouveau
  final int promoPercent;
  final bool isEnPromo;
  final bool recommande;
  final int reviewCount;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.rating = 0.0,
    this.vendeurId = '',
    this.promoPercent = 0,
    this.isEnPromo = false,
    this.recommande = false,
    this.reviewCount = 0,
  });

  // ── Prix affiché apres reduction (si promo active) ──
  double get prixActuel =>
      isEnPromo && promoPercent > 0 ? price * (1 - promoPercent / 100) : price;

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      vendeurId: map['vendeurId'] ?? '',
      promoPercent: (map['promoPercent'] as num?)?.toInt() ?? 0,
      isEnPromo: map['isEnPromo'] ?? false,
      recommande: map['recommande'] ?? false,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'category': category,
    'rating': rating,
    'vendeurId': vendeurId,
    'promoPercent': promoPercent,
    'isEnPromo': isEnPromo,
    'recommande': recommande,
    'reviewCount': reviewCount,
  };
}