import '../config/api_config.dart';

class Property {
  final int id;
  final String title;
  final String description;
  final double price;
  final String rentType; // DAILY, MONTHLY
  final String propertyType; // Apartment, House, etc.
  final String country;
  final String city;
  final String? district;
  final int bedrooms;
  final int bathrooms;
  final int guests;
  final double? area;
  final List<String> images;
  final List<String> amenities;
  final String authorName;
  final String authorEmail;
  final String authorPhone;
  final int authorId;
  final double? latitude;
  final double? longitude;
  bool isFavorite;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rentType,
    required this.propertyType,
    required this.country,
    required this.city,
    this.district,
    required this.bedrooms,
    required this.bathrooms,
    required this.guests,
    this.area,
    required this.images,
    required this.amenities,
    this.authorName = 'Арендатор',
    this.authorEmail = '',
    this.authorPhone = '',
    this.authorId = 0,
    this.isFavorite = false,
    this.latitude,
    this.longitude,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    final String baseUrl = ApiConfig.getBaseUrl();
    List<String> imagesList = (json['images'] as List<dynamic>? ?? [])
        .map((img) {
          String s = img.toString();
          if (s.startsWith('http')) return s;
          // Убеждаемся, что между доменом и путем есть ровно один слеш
          if (!s.startsWith('/')) s = '/$s';
          return '$baseUrl$s';
        })
        .toList();
    
    List<String> amenitiesList = [];
    if (json['amenities'] != null) {
      amenitiesList = (json['amenities'] as List<dynamic>).map((e) => e.toString()).toList();
    }

    return Property(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      rentType: json['rentType'] ?? 'DAILY',
      propertyType: json['propertyType'] ?? 'Apartment',
      country: json['country'] ?? 'Казахстан',
      city: json['city'] ?? 'Алматы',
      district: json['district'],
      bedrooms: json['bedrooms'] ?? 1,
      bathrooms: json['bathrooms'] ?? 1,
      guests: json['guests'] ?? 2,
      area: json['area'] != null ? (json['area'] as num).toDouble() : null,
      images: imagesList.isEmpty ? ['https://via.placeholder.com/400'] : imagesList,
      amenities: amenitiesList,
      authorName: json['author'] != null ? (json['author']['name'] ?? 'Арендатор') : 'Арендатор',
      authorEmail: json['author'] != null ? (json['author']['email'] ?? '') : '',
      authorPhone: json['author'] != null ? (json['author']['phone'] ?? '') : '',
      authorId: json['author'] != null ? (json['author']['id'] ?? json['authorId'] ?? 0) : (json['authorId'] ?? 0),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }


  // Геттеры для совместимости
  String get location => "$city, $country";
  double get rating => 5.0;
  String get type => propertyType;
}
