import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static const String baseUrl = 'https://countriesnow.space/api/v0.1/countries';

  static Future<List<String>> getCountries() async {
    try {
      final response = await http.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List).map((c) => c['country'].toString()).toList();
        list.sort();
        return list;
      }
    } catch (e) {
      print('Location error (returning fallback): $e');
    }
    return ['Kazakhstan', 'Russia', 'Turkey', 'United Arab Emirates', 'Uzbekistan', 'Georgia', 'Thailand']; // Latin Fallback
  }

  static Future<List<String>> getCities(String country) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cities'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': country}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List).map((c) => c.toString()).toList();
        list.sort();
        return list;
      }
    } catch (e) {
      print('Location API error (returning fallback): $e');
    }
    // Fallback in Latin
    if (country == 'Kazakhstan') return ['Almaty', 'Astana', 'Shymkent'];
    if (country == 'Russia') return ['Moscow', 'Saint Petersburg'];
    return [];
  }

  static Future<List<String>> getDistricts(String city) async {
    // В бесплатном API стран и городов обычно нет районов.
    // Для демонстрации добавим районы крупных городов Казахстана.
    final mocks = {
      'Almaty': ['Алмалинский', 'Бостандыкский', 'Ауэзовский', 'Медеуский', 'Жетысуский', 'Турксибский', 'Наурызбайский', 'Алатауский'],
      'Astana': ['Алматы', 'Байконур', 'Есиль', 'Нура', 'Сарыарка'],
      'Алматы': ['Алмалинский', 'Бостандыкский', 'Ауэзовский', 'Медеуский', 'Жетысуский', 'Турксибский', 'Наурызбайский', 'Алатауский'],
      'Астана': ['Алматы', 'Байконур', 'Есиль', 'Нура', 'Сарыарка'],
    };
    
    // Пытаемся найти по названию
    return mocks[city] ?? [];
  }
}
