import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/property.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import '../config/api_config.dart';

class EditPropertyPage extends StatefulWidget {
  final Property property;
  const EditPropertyPage({Key? key, required this.property}) : super(key: key);

  @override
  State<EditPropertyPage> createState() => _EditPropertyPageState();
}

class _EditPropertyPageState extends State<EditPropertyPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _bedroomsController;
  late TextEditingController _bathroomsController;
  late TextEditingController _guestsController;
  late TextEditingController _areaController;
  
  late String _propertyType;
  late String _rentType;
  late String _country;
  late String _city;
  String? _district;
  
  double? _latitude;
  double? _longitude;
  
  List<String> _amenities = [];
  List<dynamic> _mixedImages = []; // Contains Strings (urls) and Files
  bool _isLoading = false;

  List<String> countries = [];
  List<String> cities = [];
  List<String> districts = [];
  bool _isMapReady = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.property.title);
    _descriptionController = TextEditingController(text: widget.property.description);
    _priceController = TextEditingController(text: widget.property.price.toString());
    _bedroomsController = TextEditingController(text: widget.property.bedrooms.toString());
    _bathroomsController = TextEditingController(text: widget.property.bathrooms.toString());
    _guestsController = TextEditingController(text: widget.property.guests.toString());
    _areaController = TextEditingController(text: widget.property.area?.toString() ?? '');
    
    _propertyType = widget.property.propertyType;
    _rentType = widget.property.rentType;
    _country = widget.property.country;
    _city = widget.property.city;
    _district = widget.property.district;
    _amenities = List.from(widget.property.amenities);
    _mixedImages.addAll(widget.property.images);
    _latitude = widget.property.latitude;
    _longitude = widget.property.longitude;
    
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    countries = await LocationService.getCountries();
    if (_country.isNotEmpty) {
      cities = await LocationService.getCities(_country);
      if (_city.isNotEmpty) {
        districts = await LocationService.getDistricts(_city);
      }
    }
    setState(() {});
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _mixedImages.addAll(pickedFiles.map((xFile) => File(xFile.path)));
      });
    }
  }

  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final token = await AuthService().getToken();
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.getBaseUrl()}/api/properties/${widget.property.id}'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['title'] = _titleController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['propertyType'] = _propertyType;
      request.fields['rentType'] = _rentType;
      request.fields['price'] = _priceController.text;
      request.fields['bedrooms'] = _bedroomsController.text;
      request.fields['bathrooms'] = _bathroomsController.text;
      request.fields['guests'] = _guestsController.text;
      request.fields['country'] = _country;
      request.fields['city'] = _city;
      if (_district != null) request.fields['district'] = _district!;
      if (_areaController.text.isNotEmpty) request.fields['area'] = _areaController.text;
      request.fields['amenities'] = _amenities.join(',');
      
      if (_latitude != null) request.fields['latitude'] = _latitude.toString();
      if (_longitude != null) request.fields['longitude'] = _longitude.toString();

      List<String> remainingExistingImages = [];
      for (var img in _mixedImages) {
        if (img is String) {
          remainingExistingImages.add(img);
        } else if (img is File) {
          request.files.add(await http.MultipartFile.fromPath('images', img.path));
        }
      }
      request.fields['existingImages'] = jsonEncode(remainingExistingImages);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Объявление обновлено'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${response.body}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Редактировать объявление', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildTextField('Название', _titleController, 'Уютная квартира в центре'),
            const SizedBox(height: 16),
            _buildTextField('Описание', _descriptionController, 'Опишите ваше жилье', maxLines: 4),
            const SizedBox(height: 16),
            _buildDropdown('Тип недвижимости', _propertyType, ['Квартира', 'Дом', 'Вилла', 'Лофт', 'Отель'], (val) => setState(() => _propertyType = val!)),
            const SizedBox(height: 16),
            _buildDropdown('Тип аренды', _rentType, ['DAILY', 'MONTHLY'], (val) => setState(() => _rentType = val!)),
            const SizedBox(height: 16),
            _buildTextField('Цена', _priceController, '10000', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Спален', _bedroomsController, '2', keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Ванных', _bathroomsController, '1', keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Гостей', _guestsController, '4', keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField('Площадь (м²)', _areaController, '50', keyboardType: TextInputType.number, required: false),
            const SizedBox(height: 24),
            Text('Местоположение', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _buildDropdown('Страна', _country, countries, (val) async {
              setState(() {
                _country = val!;
                _city = '';
                _district = null;
              });
              cities = await LocationService.getCities(_country);
              setState(() {});
            }),
            const SizedBox(height: 16),
            _buildDropdown('Город', _city, cities, (val) async {
              setState(() {
                _city = val!;
                _district = null;
              });
              districts = await LocationService.getDistricts(_city);
              setState(() {});
            }),
            if (districts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDropdown('Район', _district ?? '', ['', ...districts], (val) => setState(() => _district = val!.isEmpty ? null : val)),
            ],
            const SizedBox(height: 24),
            Text('Точка на карте', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _latitude != null && _longitude != null 
                      ? latLng.LatLng(_latitude!, _longitude!) 
                      : latLng.LatLng(43.238949, 76.889709), // Default Almaty
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _latitude = point.latitude;
                        _longitude = point.longitude;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.kv',
                    ),
                    if (_latitude != null && _longitude != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 80.0,
                            height: 80.0,
                            point: latLng.LatLng(_latitude!, _longitude!),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40.0,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _latitude != null ? 'Выбрано: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}' : 'Нажмите на карту, чтобы выбрать точку',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text('Удобства', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['WiFi', 'Кухня', 'Парковка', 'Бассейн', 'Кондиционер', 'Стиральная машина'].map((amenity) {
                final isSelected = _amenities.contains(amenity);
                return FilterChip(
                  label: Text(amenity),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _amenities.add(amenity);
                      } else {
                        _amenities.remove(amenity);
                      }
                    });
                  },
                  selectedColor: Colors.black,
                  labelStyle: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.black),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Фотографии', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_mixedImages.isNotEmpty) ...[
              SizedBox(
                height: 500, // Высота для списка с прокруткой и перетаскиванием
                child: ReorderableListView.builder(
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Перетащите фото, чтобы изменить порядок. Первое фото - обложка.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  itemCount: _mixedImages.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _mixedImages.removeAt(oldIndex);
                      _mixedImages.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final image = _mixedImages[index];
                    return Container(
                      key: ValueKey(image.hashCode), // Уникальный ключ
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: image is String
                                ? Image.network(
                                    image.startsWith('http') ? image : '${ApiConfig.getBaseUrl()}$image',
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    image as File,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        title: Text(
                          index == 0 ? 'Главное фото' : 'Фото #${index + 1}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _mixedImages.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Добавить фото'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProperty,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text('Сохранить изменения', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, TextInputType? keyboardType, bool required = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: required ? (value) => value == null || value.isEmpty ? 'Обязательное поле' : null : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.contains(value) ? value : null,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _guestsController.dispose();
    _areaController.dispose();
    super.dispose();
  }
}