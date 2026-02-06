import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_service.dart';
import '../models/booking.dart';
import '../config/api_config.dart';

class BookingService {
  static const String baseUrl = '${ApiConfig.baseUrl}/bookings';
  final AuthService _authService = AuthService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<Booking>> getMyBookings() async {
    final token = await _authService.getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/my'), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => Booking.fromJson(e)).toList();
      }
    } catch (e) { print(e); }
    return [];
  }

  Future<List<Booking>> getOwnerBookings() async {
    final token = await _authService.getToken();
    if (token == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/owner'), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => Booking.fromJson(e)).toList();
      }
    } catch (e) { print(e); }
    return [];
  }

  Future<bool> createBooking(int propertyId, DateTime start, DateTime end, double price) async {
    final token = await _authService.getToken();
    if (token == null) return false;
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'propertyId': propertyId,
          'startDate': _dateFormat.format(start),
          'endDate': _dateFormat.format(end),
          'totalPrice': price,
        }),
      );
      return response.statusCode == 201;
    } catch (e) { print(e); }
    return false;
  }

  Future<bool> updateStatus(int bookingId, String status) async {
    final token = await _authService.getToken();
    if (token == null) {
      print('updateStatus: No token available');
      return false;
    }
    try {
      print('updateStatus: Calling API for booking $bookingId with status $status');
      final response = await http.put(
        Uri.parse('$baseUrl/$bookingId/status'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      print('updateStatus: Response status code: ${response.statusCode}');
      print('updateStatus: Response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) { 
      print('updateStatus: Exception: $e');
    }
    return false;
  }
}
