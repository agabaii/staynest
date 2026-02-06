import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/property_service.dart';
import '../services/location_service.dart';
import '../providers/app_state.dart';
import '../widgets/change_notifier_provider.dart';
import 'all_properties_page.dart';

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({Key? key}) : super(key: key);

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  int _currentStep = 0;
  
  // Data controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
   final _priceController = TextEditingController();
  final _bedroomsController = TextEditingController(text: '1');
  final _bathroomsController = TextEditingController(text: '1');
  final _guestsController = TextEditingController(text: '2');
  final _areaController = TextEditingController();
  final _customAmenityController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSearchingAddress = false;
  
  String _selectedRentType = 'DAILY';
  String _selectedPropertyType = 'Квартира';
  String? _selectedCountry;
  String? _selectedCity;
  String? _selectedDistrict;
  
  List<String> _countries = [];
  List<String> _cities = [];
  List<String> _districts = [];
  bool _isLocationLoading = false;

  // Coordinates
  double? _latitude;
  double? _longitude;
  final MapController _mapController = MapController();

  final List<String> _propertyTypes = ['Квартира', 'Дом', 'Вилла', 'Лофт', 'Отель'];
  final List<String> _availableAmenities = ['Wi-Fi', 'Кондиционер', 'Кухня', 'Стиральная машина', 'ТВ', 'Фен', 'Утюг', 'Бассейн', 'Парковка'];
  final List<String> _selectedAmenities = [];
  
  List<XFile> _images = [];
  final Map<String, Uint8List> _imageBytes = {}; // Храним байты для превью
  final ImagePicker _picker = ImagePicker();
  final _propertyService = PropertyService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() => _isLocationLoading = true);
    final list = await LocationService.getCountries();
    setState(() {
      _countries = list;
      _isLocationLoading = false;
    });
  }

  Future<void> _loadCities(String country) async {
    setState(() => _isLocationLoading = true);
    final list = await LocationService.getCities(country);
    setState(() {
      _cities = list;
      _isLocationLoading = false;
    });
  }

  Future<void> _loadDistricts(String city) async {
    setState(() => _isLocationLoading = true);
    final list = await LocationService.getDistricts(city);
    setState(() {
      _districts = list;
      _isLocationLoading = false;
    });
  }

  void _nextStep() {
    if (_currentStep < 3) setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _searchAddress() async {
    if (_addressController.text.isEmpty) return;
    
    setState(() => _isSearchingAddress = true);
    try {
      final query = Uri.encodeComponent('${_selectedCountry ?? ""} ${_selectedCity ?? ""} ${_addressController.text}');
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=3'),
        headers: {'User-Agent': 'StayNest_App_v1.0'},
      );
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          setState(() {
            _latitude = lat;
            _longitude = lon;
          });
          _mapController.move(latLng.LatLng(lat, lon), 15.0);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Адрес не найден')));
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    } finally {
      setState(() => _isSearchingAddress = false);
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      for (var file in pickedFiles) {
        final bytes = await file.readAsBytes();
        setState(() {
          _images.add(file);
          _imageBytes[file.path] = bytes;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty || _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните заголовок, цену и добавьте фото')));
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await _propertyService.createProperty(
      title: _titleController.text,
      description: _descController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      images: _images,
      rentType: _selectedRentType,
      propertyType: _selectedPropertyType,
      country: _selectedCountry ?? '',
      city: _selectedCity ?? '',
      district: _selectedDistrict ?? '',
      bedrooms: int.tryParse(_bedroomsController.text) ?? 1,
      bathrooms: int.tryParse(_bathroomsController.text) ?? 1,
      guests: int.tryParse(_guestsController.text) ?? 2,
      area: double.tryParse(_areaController.text),
      latitude: _latitude,
      longitude: _longitude,
      amenities: _selectedAmenities,
    );
    setState(() => _isSubmitting = false);

    if (result['success']) {
      // Обновляем список всех объявлений в глобальном приложении
      final state = ChangeNotifierProvider.of<AppState>(context);
      await state.fetchProperties();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Объявление успешно опубликовано!'),
        backgroundColor: Colors.green,
      ));
      
      // Переходим на страницу "Мои объявления"
      Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => const AllPropertiesPage(onlyMyProperties: true))
      );
      
      // Очищаем форму
      _titleController.clear();
      _descController.clear();
      _priceController.clear();
      _areaController.clear();
      setState(() {
        _currentStep = 0;
        _selectedCountry = null;
        _selectedCity = null;
        _selectedDistrict = null;
        _latitude = null;
        _longitude = null;
        _images.clear();
        _imageBytes.clear();
        _selectedAmenities.clear();
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Ошибка при сохранении'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Сдать жилье', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentStep == 0) _buildLocationStep(),
                  if (_currentStep == 1) _buildDetailsStep(),
                  if (_currentStep == 2) _buildAmenitiesStep(),
                  if (_currentStep == 3) _buildPhotosStep(),
                ],
              ),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(4, (index) => Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: index <= _currentStep ? Colors.black : Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Местоположение'),
        const SizedBox(height: 8),
        Text('Укажите, где находится ваш объект', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),
        
        _buildLabel('Страна'),
        _buildSearchableDropdown(
          hint: _isLocationLoading && _countries.isEmpty ? 'Загрузка стран...' : 'Выберите страну',
          items: _countries,
          value: _selectedCountry,
          onChanged: (val) {
            setState(() {
              _selectedCountry = val;
              _selectedCity = null;
              _selectedDistrict = null;
              _cities = [];
              _districts = [];
            });
            if (val != null) _loadCities(val);
          },
        ),
        const SizedBox(height: 24),
        
        if (_selectedCountry != null || _cities.isNotEmpty) ...[
          _buildLabel('Город'),
          _buildSearchableDropdown(
            hint: _isLocationLoading && _cities.isEmpty ? 'Загрузка городов...' : 'Выберите город',
            items: _cities,
            value: _selectedCity,
            onChanged: (val) {
              setState(() {
                _selectedCity = val;
                _selectedDistrict = null;
                _districts = [];
              });
              if (val != null) _loadDistricts(val);
            },
          ),
          const SizedBox(height: 24),
        ],
        
        if (_selectedCity != null || _districts.isNotEmpty) ...[
          _buildLabel('Район'),
          _districts.isNotEmpty 
            ? _buildSearchableDropdown(
                hint: 'Выберите район',
                items: _districts,
                value: _selectedDistrict,
                onChanged: (val) => setState(() => _selectedDistrict = val),
              )
            : _buildField(
                hintHint: 'Введите район',
                example: 'Например: Алмалинский район',
                onChanged: (v) => _selectedDistrict = v,
              ),
        ],

        const SizedBox(height: 24),
        _buildLabel('Точный адрес (поиск на карте)'),
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: _addressController,
                hintHint: 'Улица, дом, кв',
                example: 'пр. Абая, 10',
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSearchingAddress ? null : _searchAddress,
              icon: _isSearchingAddress 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search, color: Colors.black),
            ),
          ],
        ),

        if (_isLocationLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: LinearProgressIndicator(color: Colors.black)),
          ),
        const SizedBox(height: 32),
        Text('Точка на карте', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          'Нажмите на карту, чтобы выбрать точное местоположение',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Container(
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue[50]!,
                        Colors.blue[100]!,
                      ],
                    ),
                  ),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _latitude != null && _longitude != null 
                        ? latLng.LatLng(_latitude!, _longitude!) 
                        : latLng.LatLng(43.238949, 76.889709),
                      initialZoom: 13.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (tapPosition, point) {
                        setState(() {
                          _latitude = point.latitude;
                          _longitude = point.longitude;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.kv',
                        tileBuilder: (context, widget, tile) {
                          return ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.white.withOpacity(0.1),
                              BlendMode.lighten,
                            ),
                            child: widget,
                          );
                        },
                      ),
                      if (_latitude != null && _longitude != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 50,
                              height: 50,
                              point: latLng.LatLng(_latitude!, _longitude!),
                              child: TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.elasticOut,
                                builder: (context, double value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              // Info overlay
              if (_latitude != null && _longitude != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Местоположение выбрано',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_latitude == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Нажмите на карту или используйте поиск адреса',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.orange[900], fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Основные детали'),
        const SizedBox(height: 8),
        Text('Опишите ваше предложение кратко и ясно', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),
        _buildLabel('Тип аренды'),
        Row(
          children: [
            _buildChoiceChip('Посуточно', _selectedRentType == 'DAILY', () => setState(() => _selectedRentType = 'DAILY')),
            const SizedBox(width: 12),
            _buildChoiceChip('Помесячно', _selectedRentType == 'MONTHLY', () => setState(() => _selectedRentType = 'MONTHLY')),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabel('Вид недвижимости'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _propertyTypes.map((t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChoiceChip(t, _selectedPropertyType == t, () => setState(() => _selectedPropertyType = t)),
            )).toList(),
          ),
        ),
        const SizedBox(height: 32),
        _buildLabel('Заголовок объявления'),
        _buildField(
          controller: _titleController,
          hintHint: 'Название жилья',
          example: 'Уютная студия в центре с видом на горы',
        ),
        const SizedBox(height: 24),
        _buildLabel('Цена (${_selectedRentType == 'DAILY' ? 'за сутки' : 'за месяц'})'),
        _buildField(
          controller: _priceController,
          hintHint: 'Укажите стоимость',
          example: 'Например: 15000',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        _buildLabel('Описание'),
        _buildField(
          controller: _descController,
          hintHint: 'Расскажите подробнее...',
          example: 'Свежий ремонт, тихие соседи, 5 минут до метро. Вся техника есть.',
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Спальни'),
                  _buildField(controller: _bedroomsController, hintHint: '1', example: '', keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Ванные'),
                  _buildField(controller: _bathroomsController, hintHint: '1', example: '', keyboardType: TextInputType.number),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Гости'),
                  _buildField(controller: _guestsController, hintHint: '2', example: '', keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Площадь (м²)'),
                  _buildField(controller: _areaController, hintHint: '40', example: '', keyboardType: TextInputType.number),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenitiesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Удобства'),
        const SizedBox(height: 8),
        Text('Отметьте, что есть в вашем жилье', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            childAspectRatio: 3, 
            crossAxisSpacing: 12, 
            mainAxisSpacing: 12
          ),
          itemCount: _availableAmenities.length,
          itemBuilder: (context, index) {
            final amenity = _availableAmenities[index];
            final isSelected = _selectedAmenities.contains(amenity);
            return GestureDetector(
              onTap: () => setState(() => isSelected ? _selectedAmenities.remove(amenity) : _selectedAmenities.add(amenity)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? Colors.black : Colors.grey[200]!, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined, 
                      color: isSelected ? Colors.white : Colors.grey[400], 
                      size: 20
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        amenity, 
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.white : Colors.black87, 
                          fontWeight: FontWeight.w700, 
                          fontSize: 13
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _buildLabel('Добавить своё удобство'),
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: _customAmenityController, 
                hintHint: 'Например: джакузи, камин', 
                example: ''
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {
                if (_customAmenityController.text.isNotEmpty) {
                  setState(() {
                    final newAmenity = _customAmenityController.text.trim();
                    if (!_availableAmenities.contains(newAmenity)) {
                      _availableAmenities.add(newAmenity);
                      _selectedAmenities.add(newAmenity);
                    } else if (!_selectedAmenities.contains(newAmenity)) {
                      _selectedAmenities.add(newAmenity);
                    }
                    _customAmenityController.clear();
                  });
                }
              }, 
              icon: const Icon(Icons.add_circle, size: 32, color: Colors.black),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Фотографии'),
        const SizedBox(height: 8),
        Text('Красивые фото повышают шансы на бронирование', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 32),
        if (_images.isNotEmpty) ...[
          SizedBox(
            height: 400,
            child: ReorderableListView.builder(
              header: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Перетащите фото, чтобы изменить порядок. Первое фото - обложка.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              itemCount: _images.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _images.removeAt(oldIndex);
                  _images.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final file = _images[index];
                return Container(
                  key: ValueKey(file.path),
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
                        child: _imageBytes[file.path] != null
                            ? Image.memory(_imageBytes[file.path]!, fit: BoxFit.cover)
                            : Container(color: Colors.grey[200]),
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
                          _images.removeAt(index);
                          _imageBytes.remove(file.path);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        OutlinedButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Добавить еще фото'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -10))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prevStep, 
              child: Text('Назад', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800))
            )
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: (_currentStep == 3) ? (_isSubmitting ? null : _submit) : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, 
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: _isSubmitting 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  _currentStep == 3 ? 'Опубликовать' : 'Далее', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1));

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4), 
    child: Text(text, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87))
  );

  Widget _buildField({
    TextEditingController? controller, 
    required String hintHint, 
    required String example, 
    Function(String)? onChanged, 
    TextInputType keyboardType = TextInputType.text, 
    int maxLines = 1
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: example, // Пример как hintText
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontWeight: FontWeight.w400),
        labelText: hintHint, // Подпись как Label
        labelStyle: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w500),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.black, width: 2)),
      ),
    );
  }

  Widget _buildSearchableDropdown({
    required String hint,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50], 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          value: value,
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black54),
          borderRadius: BorderRadius.circular(20),
          dropdownColor: Colors.white,
          items: items.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(e, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87))
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[100], 
          borderRadius: BorderRadius.circular(16)
        ),
        child: Text(
          label, 
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.black87, 
            fontWeight: FontWeight.w800,
            fontSize: 14
          )
        ),
      ),
    );
  }
}
