import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';
import '../providers/app_state.dart' as import_app_state;

class PropertyService {
  static const String baseUrl = '${ApiConfig.baseUrl}/properties';
  final AuthService _authService = AuthService();

  Future<List<dynamic>> getProperties({
    double? minPrice,
    double? maxPrice,
    List<String>? amenities,
    String? sort,
    String? type,
  }) async {
    String query = '?';
    if (minPrice != null) query += 'minPrice=$minPrice&';
    if (maxPrice != null) query += 'maxPrice=$maxPrice&';
    if (amenities != null && amenities.isNotEmpty) query += 'amenities=${amenities.join(',')}&';
    if (sort != null) query += 'sort=$sort&';
    if (type != null) query += 'type=$type&';

    final response = await http.get(Uri.parse('$baseUrl$query'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> createProperty({
    required String title,
    required String description,
    required double price,
    required List<XFile> images,
    String rentType = "DAILY",
    String propertyType = "Apartment",
    String country = "Казахстан",
    String city = "Алматы",
    String district = "",
    int bedrooms = 1,
    int bathrooms = 1,
    int guests = 2,
    double? area,
    double? latitude,
    double? longitude,
    List<String> amenities = const [],
  }) async {
    final token = await _authService.getToken();
    if (token == null) return {'success': false, 'message': 'Вы не авторизованы'};

    var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
    request.headers['Authorization'] = 'Bearer $token';
    
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['price'] = price.toString();
    request.fields['rentType'] = rentType;
    request.fields['propertyType'] = propertyType;
    request.fields['country'] = country;
    request.fields['city'] = city;
    request.fields['district'] = district;
    request.fields['bedrooms'] = bedrooms.toString();
    request.fields['bathrooms'] = bathrooms.toString();
    request.fields['guests'] = guests.toString();
    if (area != null) request.fields['area'] = area.toString();
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    request.fields['amenities'] = amenities.join(',');

    for (var i = 0; i < images.length; i++) {
      final bytes = await images[i].readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'images',
        bytes,
        filename: images[i].name,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      if (response.statusCode == 403) {
        // Импортируем AppState и вызываем статический метод
        // В Dart циклические импорты разрешены, но лучше использовать navigatorKey или коллбэк
        // Но мы уже подготовили статический метод
        import_app_state.AppState.handleGlobalForbidden();
      }
      String message = 'Ошибка при создании объявления';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['message'] != null) {
          message = errorData['message'];
          if (errorData['error'] != null) {
            message += ': ${errorData['error']}';
          }
        }
      } catch (_) {}
      return {'success': false, 'message': message};
    }
  }
}
