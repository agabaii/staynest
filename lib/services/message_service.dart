import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/message.dart';
import '../config/api_config.dart';
import '../providers/app_state.dart' as import_app_state;

class MessageService {
  static const String baseUrl = '${ApiConfig.baseUrl}/messages';
  final AuthService _authService = AuthService();

  Future<List<ChatPreview>> getChats() async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChatPreview.fromJson(json)).toList();
      } else if (response.statusCode == 403) {
        import_app_state.AppState.handleGlobalForbidden();
      }
    } catch (e) {
      print('Error fetching chats: $e');
    }
    return [];
  }

  Future<List<ChatMessage>> getMessages(int otherUserId) async {
    final token = await _authService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$otherUserId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ChatMessage.fromJson(json)).toList();
      } else if (response.statusCode == 403) {
        import_app_state.AppState.handleGlobalForbidden();
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
    return [];
  }

  Future<ChatMessage?> sendMessage(int receiverId, String content, {int? propertyId}) async {
    final token = await _authService.getToken();
    if (token == null) return null;

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiverId': receiverId,
          'content': content,
          'propertyId': propertyId,
        }),
      );

      if (response.statusCode == 201) {
        return ChatMessage.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 403) {
        import_app_state.AppState.handleGlobalForbidden();
      }
    } catch (e) {
      print('Error sending message: $e');
    }
    return null;
  }
}
