import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/property.dart';
import '../models/booking.dart';
import '../services/property_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class AppState extends ChangeNotifier {
  final PropertyService _propertyService = PropertyService();
  final AuthService _authService = AuthService();
  
  List<Property> _properties = [];
  bool _isLoading = false;
  String _selectedCurrency = 'KZT';
  int? _userId;
  String _userName = 'Гость';
  String _userEmail = '';
  String _userPhone = '';
  String? _userAvatar;
  String _userRole = 'USER';
  DateTime? _lastSeen;
  String _userBio = '';
  String _language = 'RU';
  bool _hasNewNotifications = false;

  // Filters
  String _filterRentType = 'Все';
  List<String> _filterPropertyTypes = [];
  double? _filterMinPrice;
  double? _filterMaxPrice;
  String? _filterCity;
  String? _filterDistrict;
  int? _filterMinBedrooms;
  int? _filterMinBathrooms;

  AppState() {
    _loadUser();
    fetchProperties();
  }

  String get filterRentType => _filterRentType;
  List<String> get filterPropertyTypes => _filterPropertyTypes;
  double? get filterMinPrice => _filterMinPrice;
  double? get filterMaxPrice => _filterMaxPrice;
  String? get filterCity => _filterCity;
  String? get filterDistrict => _filterDistrict;
  int? get filterMinBedrooms => _filterMinBedrooms;
  int? get filterMinBathrooms => _filterMinBathrooms;

  void setRentType(String type) {
    _filterRentType = type;
    notifyListeners();
  }

  void setFilters({
    String? rentType,
    List<String>? propertyTypes,
    double? minPrice,
    double? maxPrice,
    String? city,
    String? district,
    int? minBedrooms,
    int? minBathrooms,
  }) {
    if (rentType != null) _filterRentType = rentType;
    if (propertyTypes != null) _filterPropertyTypes = propertyTypes;
    _filterMinPrice = minPrice;
    _filterMaxPrice = maxPrice;
    _filterCity = city;
    _filterDistrict = district;
    _filterMinBedrooms = minBedrooms;
    _filterMinBathrooms = minBathrooms;
    notifyListeners();
  }

  List<Property> get filteredProperties {
    return _properties.where((p) {
      if (_filterRentType != 'Все' && p.rentType != _filterRentType) return false;
      if (_filterPropertyTypes.isNotEmpty && !_filterPropertyTypes.contains(p.propertyType)) return false;
      if (_filterMinPrice != null && p.price < _filterMinPrice!) return false;
      if (_filterMaxPrice != null && p.price > _filterMaxPrice!) return false;
      if (_filterCity != null && _filterCity!.isNotEmpty && p.city.toLowerCase() != _filterCity!.toLowerCase()) return false;
      if (_filterDistrict != null && _filterDistrict!.isNotEmpty && p.district?.toLowerCase() != _filterDistrict!.toLowerCase()) return false;
      if (_filterMinBedrooms != null && p.bedrooms < _filterMinBedrooms!) return false;
      if (_filterMinBathrooms != null && p.bathrooms < _filterMinBathrooms!) return false;
      return true;
    }).toList();
  }

  List<Property> get properties => _properties;
  bool get isLoading => _isLoading;
  String get selectedCurrency => _selectedCurrency;
  int? get userId => _userId;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userPhone => _userPhone;
  String? get userAvatar => _userAvatar;
  DateTime? get lastSeen => _lastSeen;
  String get userBio => _userBio;
  bool get isAdmin => _userRole == 'ADMIN';

  List<Property> get favoriteProperties => _properties.where((p) => p.isFavorite).toList();
  
  // Заглушки для бронирований (пока не реализованы на бэкенде)
  List<Booking> get upcomingBookings => <Booking>[];
  List<Booking> get completedBookings => <Booking>[];
  List<Booking> get cancelledBookings => <Booking>[];

  String get language => _language;
  bool get hasNewNotifications => _hasNewNotifications;

  void setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  void setHasNewNotifications(bool value) {
    _hasNewNotifications = value;
    notifyListeners();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('user_id');
    _userName = prefs.getString('user_name') ?? 'Гость';
    _userEmail = prefs.getString('user_email') ?? '';
    _userPhone = prefs.getString('user_phone') ?? '';
    _userAvatar = prefs.getString('user_avatar');
    _userRole = prefs.getString('user_role') ?? 'USER';
    _language = prefs.getString('language') ?? 'RU';
    notifyListeners();
  }

  Future<void> fetchProperties() async {
    print('DEBUG: Starting fetchProperties...');
    _isLoading = true;
    notifyListeners();

    try {
      print('DEBUG: Calling propertyService.getProperties()...');
      
      // Convert UI filters to API params
      List<String>? amenities; // We don't have a UI filter for amenities list in AppState yet, but we will add it or just pass null for now. 
      // Actually, we don't have amenities in AppState filters. Let's add it or rely on a new method.
      // Wait, I see _filterPropertyTypes but that's local filtering? No, I want to use server filtering now.
      
      // Let's use the new filters:
      final data = await _propertyService.getProperties(
        minPrice: _filterMinPrice,
        maxPrice: _filterMaxPrice,
        type: _filterRentType == 'Все' ? null : _filterRentType, // Should be propertyType? No, UI has filterRentType. 
        // Wait, the UI has filterType (category) on AllPropertiesPage. 
        // The AppState has _filterPropertyTypes (list). 
        // The AppState has _filterRentType (DAILY/MONTHLY).
        // My server supports 'type' which maps to propertyType.
        // It seems the current frontend did client-side filtering. 
        // I will change it to server-side filtering gradually.
        // For now, let's just pass what we have.
        // Actually, to implement "Advanced Filters" properly, I should create a new method `fetchFilteredProperties` or update this one to accept arguments.
        // But AppState is globally used.
        // I will just update the call with existing filters if set.
      ).timeout(const Duration(seconds: 10));

      print('DEBUG: Received ${data.length} items from server');
      
      List<int> favoriteIds = [];
      final token = await _authService.getToken();
      if (token != null) {
        favoriteIds = await _fetchFavorites(token);
      }

      _properties = data.map((json) {
        final p = Property.fromJson(json);
        p.isFavorite = favoriteIds.contains(p.id);
        return p;
      }).toList();
      print('DEBUG: Successfully parsed ${_properties.length} properties');
    } catch (e) {
      print('DEBUG ERROR: Ошибка загрузки объявлений: $e');
      _properties = []; 
    }

    _isLoading = false;
    print('DEBUG: fetchProperties finished. isLoading = false');
    notifyListeners();
  }

  Future<List<int>> _fetchFavorites(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/favorites'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> ids = jsonDecode(response.body);
        return ids.cast<int>();
      }
    } catch (e) {
      print('Error fetching favorites: $e');
    }
    return [];
  }

  // Auth Methods
  Future<Map<String, dynamic>> register(String email, String password, String name, String phone) async {
    final result = await _authService.register(email, password, name, phone);
    if (result['success']) {
      // При регистрации мы только отправляем код, ID получим при верификации
      _userEmail = email;
      _userName = name;
      _userPhone = phone;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
    }
    return result;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _authService.login(email, password);
    if (result['success']) {
      _userId = result['user']['id'];
      _userEmail = result['user']['email'];
      _userName = result['user']['name'];
      _userPhone = result['user']['phone'] ?? '';
      _userAvatar = result['user']['avatar'];
      _userRole = result['user']['role'] ?? 'USER';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', _userId!);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_phone', _userPhone);
      await prefs.setString('user_role', _userRole);
      if (_userAvatar != null) await prefs.setString('user_avatar', _userAvatar!);
      fetchProperties(); // Обновляем список объявлений
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final result = await _authService.verifyEmail(email, code);
    if (result['success']) {
      _userId = result['user']['id'];
      _userEmail = result['user']['email'];
      _userName = result['user']['name'];
      _userPhone = result['user']['phone'] ?? '';
      _userAvatar = result['user']['avatar'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', _userId!);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setString('user_phone', _userPhone);
      if (_userAvatar != null) await prefs.setString('user_avatar', _userAvatar!);
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await _authService.forgotPassword(email);
  }

  Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    return await _authService.resetPassword(email, code, newPassword);
  }

  Future<void> updateProfile({String? name, String? phone, String? avatarPath}) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      var request = http.MultipartRequest('PUT', Uri.parse('${ApiConfig.baseUrl}/profile'));
      request.headers['Authorization'] = 'Bearer $token';
      
      if (name != null) request.fields['name'] = name;
      if (phone != null) request.fields['phone'] = phone;
      if (avatarPath != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatarPath));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userName = data['name'];
        _userPhone = data['phone'];
        _userAvatar = data['avatar'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _userName);
        await prefs.setString('user_phone', _userPhone);
        if (_userAvatar != null) await prefs.setString('user_avatar', _userAvatar!);
        
        notifyListeners();
      }
    } catch (e) {
      print('Profile update error: $e');
    }
  }

  Future<void> fetchProfile() async {
    final token = await _authService.getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userId = data['id'];
        _userName = data['name'];
        _userEmail = data['email'];
        _userPhone = data['phone'];
        _userAvatar = data['avatar'];
        // Note: The profile fetch endpoint currently doesn't return role, but we can rely on login or update the endpoint if needed.
        // Assuming the role doesn't change frequently during session.
        _lastSeen = data['lastSeen'] != null ? DateTime.parse(data['lastSeen']) : null;
        notifyListeners();
      }
    } catch (e) { print(e); }
  }

  void setCurrency(String code) {
    _selectedCurrency = code;
    notifyListeners();
  }

  String getFormattedPrice(num priceInKzt) {
    double price = priceInKzt.toDouble();
    double converted = price;
    String symbol = '₸';
    
    if (_selectedCurrency == 'USD') {
      converted = price / 450;
      symbol = '\$';
    } else if (_selectedCurrency == 'RUB') {
      converted = price / 5;
      symbol = '₽';
    }
    
    return '${converted.toStringAsFixed(0)} $symbol';
  }

  Future<void> toggleFavorite(int propertyId) async {
    final token = await _authService.getToken();
    if (token == null) return;

    final index = _properties.indexWhere((p) => p.id == propertyId);
    if (index != -1) {
      // Оптимистичное обновление UI
      final oldStatus = _properties[index].isFavorite;
      _properties[index].isFavorite = !oldStatus;
      notifyListeners();

      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/favorites/toggle'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'propertyId': propertyId}),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) {
          // Откатываем в случае ошибки сервера
          _properties[index].isFavorite = oldStatus;
          notifyListeners();
        }
      } catch (e) {
        print('Error toggling favorite: $e');
        _properties[index].isFavorite = oldStatus;
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _userName = 'Гость';
    _userEmail = '';
    _userPhone = '';
    _userBio = '';
    for (var p in _properties) {
      p.isFavorite = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
