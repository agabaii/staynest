import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/property.dart';
import '../providers/app_state.dart';
import '../widgets/change_notifier_provider.dart';
import 'property_detail_page.dart';
import 'favorites_page.dart';
import 'messages_page.dart';
import 'profile_page.dart';
import 'add_property_page.dart';
import 'hot_deals_page.dart';
import '../services/location_service.dart';
import '../config/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ExploreTab(),
    const FavoritesPage(),
    const AddPropertyPage(),
    const MessagesPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey[400],
              elevation: 0,
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Поиск'),
                const BottomNavigationBarItem(icon: Icon(Icons.favorite_outline_rounded), label: 'Избранное'),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: Icon(Icons.add, color: Colors.white, size: 24),
                  ), 
                  label: 'Сдать'
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded),
                      if (ChangeNotifierProvider.of<AppState>(context).hasNewNotifications)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ), 
                  label: 'Сообщения'
                ),
                const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Профиль'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExploreTab extends StatefulWidget {
  const ExploreTab({Key? key}) : super(key: key);

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  String selectedPropertyType = 'Все';
  final List<String> categories = ['Все', 'Квартира', 'Дом', 'Вилла', 'Лофт', 'Отель'];
  
  // Search and Sort
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, price_low, price_high, rating

  void _showFilterSheet(AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(state: state),
    );
  }
  
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сортировка', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _buildSortOption('Сначала новые', 'newest'),
            _buildSortOption('Сначала дешевые', 'price_low'),
            _buildSortOption('Сначала дорогие', 'price_high'),
            _buildSortOption('По рейтингу', 'rating'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(label, style: GoogleFonts.inter(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.black) : null,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    
    // Apply category filter
    var filtered = state.filteredProperties.where((p) {
      return selectedPropertyType == 'Все' || p.propertyType == selectedPropertyType;
    }).toList();
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final query = _searchQuery.toLowerCase();
        return p.title.toLowerCase().contains(query) ||
               p.description.toLowerCase().contains(query) ||
               p.city.toLowerCase().contains(query) ||
               p.country.toLowerCase().contains(query) ||
               (p.district?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'price_low':
          return a.price.compareTo(b.price);
        case 'price_high':
          return b.price.compareTo(a.price);
        case 'rating':
          // Assuming rating is available, for now use id as placeholder
          return b.id.compareTo(a.id);
        case 'newest':
        default:
          return b.id.compareTo(a.id); // Newer properties have higher IDs
      }
    });

    return RefreshIndicator(
      onRefresh: () => state.fetchProperties(),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            floating: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Поиск города или жилья',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontWeight: FontWeight.w500),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.black, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Lottie.asset(
                    'assets/animations/splash.json',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'StayNest',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.black),
                onPressed: _showSortSheet,
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.black),
                onPressed: () => _showFilterSheet(state),
              ),
            ],
          ),
          
          // Категории жилья
          SliverToBoxAdapter(
            child: Container(
              height: 90,
              margin: const EdgeInsets.only(top: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: categories.length,
                itemBuilder: (context, index) => _buildCategoryIcon(categories[index]),
              ),
            ),
          ),
          
          // Hot Deals Section
          SliverToBoxAdapter(child: _buildDiscountSection(state)),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),

          // Список объектов
          state.isLoading 
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.black)))
            : filtered.isEmpty 
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Пока нет объявлений',
                          style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty ? 'Попробуйте изменить запрос' : 'Станьте первым, кто сдаст свое жилье!',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400])
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPropertyCard(filtered[index], state),
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(String category) {
    bool isSelected = selectedPropertyType == category;
    IconData icon;
    switch(category) {
      case 'Квартира': icon = Icons.apartment; break;
      case 'Дом': icon = Icons.home; break;
      case 'Вилла': icon = Icons.pool; break;
      case 'Отель': icon = Icons.hotel; break;
      default: icon = Icons.apps;
    }

    return GestureDetector(
      onTap: () => setState(() => selectedPropertyType = category),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey[400], size: 24),
            ),
            const SizedBox(height: 6),
            Text(category, style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection(AppState state) {
    return FutureBuilder<List>(
      key: ValueKey('discounts_$selectedPropertyType'), // Force reload when category changes
      future: http.get(Uri.parse('${ApiConfig.getBaseUrl()}/api/properties/discounts')).then((res) {
        if (res.statusCode == 200) return jsonDecode(res.body) as List;
        return [] as List;
      }).catchError((e) {
        return [] as List;
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final allDiscounts = snapshot.data ?? [];
        
        final filteredDiscounts = allDiscounts.where((item) {
          try {
            final p = item['property'];
            if (p == null) return false;
            final property = Property.fromJson(p);
            
            // 1. Фильтр по типу жилья (Категория)
            if (selectedPropertyType != 'Все') {
              final mapping = {
                'Квартира': 'Apartment',
                'Дом': 'House',
                'Вилла': 'Villa',
                'Отель': 'Hotel',
                'Лофт': 'Loft'
              };
              final mappedType = mapping[selectedPropertyType] ?? selectedPropertyType;
              final pType = property.propertyType.toLowerCase().trim();
              if (pType != selectedPropertyType.toLowerCase().trim() && 
                  pType != mappedType.toLowerCase().trim()) return false;
            }

            // 2. Фильтр по городу (Локация из AppState)
            if (state.filterCity != null && state.filterCity!.isNotEmpty) {
              if (property.city.toLowerCase().trim() != state.filterCity!.toLowerCase().trim()) return false;
            }

            // 3. Фильтр по поисковому запросу
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matches = property.title.toLowerCase().contains(query) ||
                             property.city.toLowerCase().contains(query) ||
                             (property.district?.toLowerCase().contains(query) ?? false);
              if (!matches) return false;
            }

            // 4. Фильтр по цене (из AppState)
            final discountPrice = item['price'] as num;
            if (state.filterMinPrice != null && discountPrice < state.filterMinPrice!) return false;
            if (state.filterMaxPrice != null && discountPrice > state.filterMaxPrice!) return false;

            return true;
          } catch (e) {
            return false;
          }
        }).toList();

        if (filteredDiscounts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Горящие предложения 🔥', 
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => HotDealsPage(
                          discounts: filteredDiscounts, 
                          category: selectedPropertyType
                        )
                      )
                    ),
                    child: Text(
                      'Все', 
                      style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.w700, fontSize: 14)
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredDiscounts.length,
                itemBuilder: (context, index) {
                  final item = filteredDiscounts[index];
                  final p = item['property'];
                  final datesList = item['dates'] as List?;
                  final dates = (datesList ?? []).map((d) => DateTime.tryParse(d.toString()) ?? DateTime.now()).toList();
                  dates.sort();
                  final price = (item['price'] ?? 0.0).toDouble();

                  late Property property;
                  try {
                    property = Property.fromJson(p);
                  } catch (e) {
                    return const SizedBox.shrink();
                  }
                  
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property))),
                    child: Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(property.images.isNotEmpty ? property.images[0] : ''),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                            child: Text('Скидка', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          Text(property.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1),
                          const SizedBox(height: 4),
                          if (dates.isNotEmpty)
                            Text(
                              'Даты: ${DateFormat('dd.MM').format(dates.first)} - ${DateFormat('dd.MM').format(dates.last)}',
                              style: GoogleFonts.inter(color: Colors.grey[200], fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                price > 0 ? state.getFormattedPrice(price) : 'АКЦИЯ!', 
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)
                              ),
                              if (price > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  state.getFormattedPrice(property.price),
                                  style: GoogleFonts.inter(
                                    color: Colors.white60, 
                                    fontSize: 13, 
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.white60
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildPropertyCard(Property property, AppState state) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: CachedNetworkImage(
                      imageUrl: property.images[0], 
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                    ),
                  ),
                ),
                Positioned(
                  top: 15, 
                  right: 15, 
                  child: GestureDetector(
                    onTap: () => state.toggleFavorite(property.id),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: Icon(
                        property.isFavorite ? Icons.favorite : Icons.favorite_border, 
                        color: property.isFavorite ? Colors.red : Colors.black, 
                        size: 20
                      ),
                    ),
                  )
                ),
                if (property.rentType == 'MONTHLY') 
                  Positioned(
                    top: 15, 
                    left: 15, 
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                      child: Text('Месяц', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title, 
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${property.city}, ${property.country}', 
                        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: Colors.black),
                    const SizedBox(width: 4),
                    Text('4.0', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            RichText(text: TextSpan(
              style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              children: [
                TextSpan(text: state.getFormattedPrice(property.price)),
                TextSpan(text: property.rentType == 'DAILY' ? ' / сутки' : ' / месяц', style: GoogleFonts.inter(fontWeight: FontWeight.w400, color: Colors.grey[500], fontSize: 13)),
              ]
            )),
          ],
        ),
      ),
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final AppState state;
  const FilterBottomSheet({Key? key, required this.state}) : super(key: key);

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String rentType;
  late List<String> selectedTypes;
  late TextEditingController minPrice;
  late TextEditingController maxPrice;
  late TextEditingController minBedrooms;
  late TextEditingController minBathrooms;
  
  List<String> countries = ['Kazakhstan', 'Russia', 'Turkey', 'United Arab Emirates', 'Thailand', 'Georgia', 'Uzbekistan'];
  List<String> cities = [];
  List<String> districts = [];
  String? selectedCountry;
  String? selectedCity;
  String? selectedDistrict;
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    rentType = widget.state.filterRentType;
    selectedTypes = List.from(widget.state.filterPropertyTypes);
    minPrice = TextEditingController(text: widget.state.filterMinPrice?.toString() ?? '');
    maxPrice = TextEditingController(text: widget.state.filterMaxPrice?.toString() ?? '');
    minBedrooms = TextEditingController(text: widget.state.filterMinBedrooms?.toString() ?? '');
    minBathrooms = TextEditingController(text: widget.state.filterMinBathrooms?.toString() ?? '');
    selectedCity = widget.state.filterCity;
    selectedDistrict = widget.state.filterDistrict;
    _loadCountries();
  }

  void _loadCountries() async {
    setState(() => _isLoadingLocations = true);
    try {
      final list = await LocationService.getCountries();
      if (mounted && list.isNotEmpty) {
        setState(() {
          countries = list;
          _isLoadingLocations = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingLocations = false);
      }
    } catch (e) {
      print('Error loading countries in filter: $e');
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Фильтры', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Вид аренды'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildChoiceChip('Все', rentType == 'Все', () => setState(() => rentType = 'Все')),
                      const SizedBox(width: 12),
                      _buildChoiceChip('Посуточно', rentType == 'DAILY', () => setState(() => rentType = 'DAILY')),
                      const SizedBox(width: 12),
                      _buildChoiceChip('Помесячно', rentType == 'MONTHLY', () => setState(() => rentType = 'MONTHLY')),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('Вид недвижимости'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Квартира', 'Дом', 'Вилла', 'Лофт', 'Отель'].map((type) {
                      bool isSelected = selectedTypes.contains(type);
                      return _buildChoiceChip(type, isSelected, () {
                        setState(() {
                          if (isSelected) selectedTypes.remove(type);
                          else selectedTypes.add(type);
                        });
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('Цена'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput(minPrice, 'Мин')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInput(maxPrice, 'Макс')),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('Местоположение'),
                  if (_isLoadingLocations)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(color: Colors.black),
                    ),
                  const SizedBox(height: 12),
                  _buildLabelSmall('Страна'),
                  _buildSearchableDropdown(
                    hint: 'Выберите страну',
                    items: countries,
                    value: selectedCountry,
                    onChanged: (val) {
                      setState(() {
                        selectedCountry = val;
                        selectedCity = null;
                        selectedDistrict = null;
                        // Сразу показываем базовые города для популярных стран
                        if (val == 'Kazakhstan') {
                          cities = ['Almaty', 'Astana', 'Shymkent', 'Karaganda', 'Aktobe'];
                        } else if (val == 'Russia') {
                          cities = ['Moscow', 'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg'];
                        } else if (val == 'Turkey') {
                          cities = ['Istanbul', 'Ankara', 'Antalya', 'Izmir'];
                        } else if (val == 'United Arab Emirates') {
                          cities = ['Dubai', 'Abu Dhabi', 'Sharjah'];
                        } else {
                          cities = [];
                        }
                        districts = [];
                      });
                      if (val != null) _loadCities(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedCountry != null) ...[
                    _buildLabelSmall('Город'),
                    _buildSearchableDropdown(
                      hint: 'Выберите город',
                      items: cities,
                      value: selectedCity,
                      onChanged: (val) {
                        setState(() {
                          selectedCity = val;
                          selectedDistrict = null;
                          districts = [];
                        });
                        if (val != null) _loadDistricts(val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (selectedCity != null && districts.isNotEmpty) ...[
                    _buildLabelSmall('Район'),
                    _buildSearchableDropdown(
                      hint: 'Все районы',
                      items: ['Все районы', ...districts],
                      value: selectedDistrict,
                      onChanged: (val) => setState(() => selectedDistrict = (val == 'Все районы') ? null : val),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildLabel('Комнаты и удобства'),
                  const SizedBox(height: 12),
                  _buildLabelSmall('Мин. спален'),
                  Row(
                    children: [1, 2, 3, 4, 5].map((count) {
                      bool isSelected = minBedrooms.text == count.toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildChoiceChip(count == 5 ? '5+' : count.toString(), isSelected, () {
                          setState(() => minBedrooms.text = count.toString());
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildLabelSmall('Мин. ванных комнат'),
                  Row(
                    children: [1, 2, 3, 4].map((count) {
                      bool isSelected = minBathrooms.text == count.toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildChoiceChip(count == 4 ? '4+' : count.toString(), isSelected, () {
                          setState(() => minBathrooms.text = count.toString());
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                widget.state.setFilters(
                  rentType: rentType,
                  propertyTypes: selectedTypes,
                  minPrice: double.tryParse(minPrice.text),
                  maxPrice: double.tryParse(maxPrice.text),
                  city: selectedCity,
                  district: selectedDistrict,
                  minBedrooms: int.tryParse(minBedrooms.text),
                  minBathrooms: int.tryParse(minBathrooms.text),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Показать результаты', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _loadCities(String country) async {
    setState(() => _isLoadingLocations = true);
    try {
      final list = await LocationService.getCities(country);
      if (mounted && list.isNotEmpty) {
        setState(() {
          cities = list;
          _isLoadingLocations = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingLocations = false);
      }
    } catch (e) {
      print('Error loading cities in filter: $e');
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  void _loadDistricts(String city) async {
    setState(() => _isLoadingLocations = true);
    try {
      final list = await LocationService.getDistricts(city);
      if (mounted) {
        setState(() {
          districts = list;
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      print('Error loading districts in filter: $e');
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  Widget _buildLabel(String text) => Text(text, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800));
  Widget _buildLabelSmall(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])));

  Widget _buildSearchableDropdown({required String hint, required List<String> items, String? value, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

}
