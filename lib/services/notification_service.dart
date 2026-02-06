import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/booking.dart'; // Contains NotificationModel
import '../config/api_config.dart';

class NotificationService {
  static const String baseUrl = '${ApiConfig.baseUrl}/notifications';
  final AuthService _authService = AuthService();

  Future<List<NotificationModel>> getNotifications() async {
    final token = await _authService.getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => NotificationModel.fromJson(e)).toList();
      }
    } catch (e) { print(e); }
    return [];
  }

  Future<void> markAllAsRead() async {
    final token = await _authService.getToken();
    if (token == null) return;
    try {
      await http.put(Uri.parse('$baseUrl/read-all'), headers: {'Authorization': 'Bearer $token'});
    } catch (e) { print(e); }
  }
}
