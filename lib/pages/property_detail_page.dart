import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/property.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../widgets/change_notifier_provider.dart';
import '../widgets/fullscreen_gallery.dart';
import '../widgets/review_card.dart';
import 'chat_detail_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';


class PropertyDetailPage extends StatefulWidget {
  final Property property;

  const PropertyDetailPage({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}
class _PropertyDetailPageState extends State<PropertyDetailPage> {
  int _currentImageIndex = 0;
  DateTimeRange? _selectedDateRange;
  // Для календаря
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedStartDay;
  DateTime? _selectedEndDay;
  
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _calendarKey = GlobalKey();
  
  bool _isBooking = false;
  Map<String, dynamic> _calendarData = {};
  List<dynamic> _existingBookings = [];
  bool _isLoadingCalendar = true;
  
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;
  double _averageRating = 0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
    _loadReviews();
  }

  Future<void> _loadCalendar() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/properties/${widget.property.id}/calendar')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/properties/${widget.property.id}/bookings')),
      ]);

      if (responses[0].statusCode == 200) {
        final List data = jsonDecode(responses[0].body);
        final Map<String, dynamic> mapped = {};
        for (var item in data) {
          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(item['date']));
          mapped[dateStr] = item;
        }
        _calendarData = mapped;
      }

      if (responses[1].statusCode == 200) {
        _existingBookings = jsonDecode(responses[1].body);
      }

      setState(() => _isLoadingCalendar = false);
    } catch (e) {
      print(e);
      setState(() => _isLoadingCalendar = false);
    }
  }

  void _onDaySelected(DateTime day) {
     final dateStr = DateFormat('yyyy-MM-dd').format(day);
     // 1. Проверяем блокировку или занятость
     if (_calendarData[dateStr]?['isBlocked'] == true) return;
     for (var b in _existingBookings) {
        final start = DateTime.parse(b['startDate']).toLocal();
        final end = DateTime.parse(b['endDate']).toLocal();
        if ((day.isAfter(start) || DateUtils.isSameDay(day, start)) && 
            (day.isBefore(end) || DateUtils.isSameDay(day, end))) {
          return; // Занято
        }
     }

     setState(() {
       // Логика выбора диапазона или одной даты
       if (_selectedStartDay == null || (_selectedStartDay != null && _selectedEndDay != null)) {
         _selectedStartDay = day;
         _selectedEndDay = null; // Сброс при новом выборе
         _selectedDateRange = null;
       } else if (_selectedStartDay != null && _selectedEndDay == null) {
          // Выбираем конец
          if (day.isBefore(_selectedStartDay!)) {
            _selectedStartDay = day; // Если выбрали дату раньше
          } else {
             // Проверяем, нет ли занятых дней МЕЖДУ start и end
             bool hasBlockedDays = false;
             DateTime check = _selectedStartDay!.add(const Duration(days: 1));
             while(check.isBefore(day)) {
                final dStr = DateFormat('yyyy-MM-dd').format(check);
                if (_calendarData[dStr]?['isBlocked'] == true) hasBlockedDays = true;
                 for (var b in _existingBookings) {
                    final start = DateTime.parse(b['startDate']).toLocal();
                    final end = DateTime.parse(b['endDate']).toLocal();
                    if ((check.isAfter(start) || DateUtils.isSameDay(check, start)) && 
                        (check.isBefore(end) || DateUtils.isSameDay(check, end))) {
                      hasBlockedDays = true;
                    }
                 }
                check = check.add(const Duration(days: 1));
             }

             if (!hasBlockedDays) {
                _selectedEndDay = day;
                _selectedDateRange = DateTimeRange(start: _selectedStartDay!, end: _selectedEndDay!);
             } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выбранный диапазоне содержит недоступные даты')));
               _selectedStartDay = day; // Начинаем новый выбор отсюда
             }
          }
       }
     });
  }

  Future<bool> _showPaymentSheet(BuildContext context, double total) async {
    bool isProcessing = false;
    final cardController = TextEditingController();
    final dateController = TextEditingController();
    final cvvController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              top: 32, left: 24, right: 24
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Оплата', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Сумма к оплате: ${total.toStringAsFixed(0)}₸', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 24),
                TextField(
                  controller: cardController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Номер карты',
                    hintText: '0000 0000 0000 0000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'Срок действия',
                          hintText: 'ММ/ГГ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: cvvController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : () async {
                      setModalState(() => isProcessing = true);
                      await Future.delayed(const Duration(seconds: 2)); // Симуляция
                      if (mounted) Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isProcessing 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Оплатить ${total.toStringAsFixed(0)}₸', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBooking() async {
    if (_selectedStartDay == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите даты')));
       return;
    }
    
    // Если выбран только старт, считаем это как бронь на 1 ночь
    final start = _selectedStartDay!;
    final end = _selectedEndDay ?? _selectedStartDay!; 
    
    final state = ChangeNotifierProvider.of<AppState>(context);
    if (state.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт, чтобы забронировать')));
      return;
    }

    setState(() => _isBooking = true);

    double totalPrice = 0;
    final daysCount = end.difference(start).inDays + 1; // +1 чтобы включить оба дня
    
    print('=== BOOKING DEBUG ===');
    print('Start: ${DateFormat('yyyy-MM-dd').format(start)}');
    print('End: ${DateFormat('yyyy-MM-dd').format(end)}');
    print('Days count: $daysCount');
    
    // Считаем цену за каждый день включительно
    for (int i = 0; i < daysCount; i++) {
      final date = start.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayData = _calendarData[dateStr];
      final dayPrice = (dayData != null && dayData['price'] != null) 
          ? (dayData['price'] as num).toDouble() 
          : widget.property.price;
      print('Day $dateStr: $dayPrice');
      totalPrice += dayPrice;
    }
    
    print('Total price: $totalPrice');
    print('===================');

    // Запрос на бронирование (БЕЗ ОПЛАТЫ НА ЭТОМ ЭТАПЕ)
    final success = await BookingService().createBooking(
      widget.property.id,
      start,
      end,
      totalPrice,
    );

    setState(() => _isBooking = false);

    if (success) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Заявка отправлена'),
            content: Text('Хозяин получит уведомление. После того как он подтвердит бронь, вы сможете её оплатить в разделе "Мои поездки".\n\nИтоговая сумма: ${totalPrice.toStringAsFixed(0)} ₸'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно')),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при отправке заявки'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadReviews() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/properties/${widget.property.id}/reviews')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/properties/${widget.property.id}/rating')),
      ]);

      if (responses[0].statusCode == 200) {
        final List data = jsonDecode(responses[0].body);
        _reviews = data.cast<Map<String, dynamic>>();
      }

      if (responses[1].statusCode == 200) {
        final ratingData = jsonDecode(responses[1].body);
        _averageRating = (ratingData['averageRating'] as num).toDouble();
        _reviewCount = ratingData['reviewCount'] as int;
      }

      setState(() => _isLoadingReviews = false);
    } catch (e) {
      print('Error loading reviews: $e');
      setState(() => _isLoadingReviews = false);
    }
  }



  Future<void> _handleDelete(BuildContext context, AppState state) async {
     final confirm = await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Удалить объявление?'),
         content: const Text('Вы уверены? Это действие нельзя отменить.'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
           TextButton(
             onPressed: () => Navigator.pop(context, true), 
             child: const Text('Удалить', style: TextStyle(color: Colors.red))
           ),
         ],
       ),
     );

     if (confirm == true) {
         final token = await AuthService().getToken();
         if (token != null) {
           await http.delete(
             Uri.parse('${ApiConfig.baseUrl}/properties/${widget.property.id}'),
             headers: {'Authorization': 'Bearer $token'},
           );
           if (mounted) {
            Navigator.pop(context); // Close details
            state.fetchProperties(); // Refresh list
           }
         }
     }
  }

  void _showReportDialog(BuildContext context) {
    String reason = 'Мошенничество';
    final reasons = ['Мошенничество', 'Неверное описание', 'Грубость хозяина', 'Спам', 'Другое'];
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Пожаловаться'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Причина'),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => reason = v!),
                ),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(labelText: 'Подробности (необязательно)'),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              TextButton(
                onPressed: () async {
                   final token = await AuthService().getToken();
                   if (token == null) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нужно войти в аккаунт')));
                     return;
                   }
                   
                   try {
                     await http.post(
                       Uri.parse('${ApiConfig.baseUrl}/reports'),
                       headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json'
                       },
                       body: jsonEncode({
                         'reason': reason,
                         'details': detailsController.text,
                         'propertyId': widget.property.id
                       })
                     );
                     Navigator.pop(context);
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Жалоба отправлена. Спасибо!')));
                   } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка отправки')));
                   }
                },
                child: const Text('Отправить'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    int rating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ваш отзыв'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setState(() => rating = index + 1),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              TextButton(
                onPressed: () async {
                   final token = await AuthService().getToken();
                   if (token == null) return;
                   
                   try {
                     final response = await http.post(
                       Uri.parse('${ApiConfig.baseUrl}/reviews'),
                       headers: {
                        'Authorization': 'Bearer $token',
                        'Content-Type': 'application/json'
                       },
                       body: jsonEncode({
                         'rating': rating,
                         'comment': commentController.text,
                         'propertyId': widget.property.id
                       })
                     );
                     
                     if (response.statusCode == 200) {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отзыв опубликован!')));
                         _loadReviews(); // Refresh reviews
                     } else {
                         final msg = jsonDecode(response.body)['message'] ?? 'Ошибка';
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                         Navigator.pop(context); // Close anyway if duplicate
                     }
                   } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка отправки')));
                   }
                },
                child: const Text('Отправить'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: size.height * 0.5,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: Icon(
                          widget.property.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: widget.property.isFavorite ? Colors.red : Colors.black,
                          size: 20,
                        ),
                        onPressed: () => state.toggleFavorite(widget.property.id),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: PopupMenuButton<String>(
                         icon: const Icon(Icons.more_vert, color: Colors.black, size: 20),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         itemBuilder: (context) => [
                            if (state.isAdmin)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: Colors.red))]),
                              ),
                            const PopupMenuItem(
                              value: 'report',
                              child: Row(children: [Icon(Icons.flag, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Пожаловаться')]),
                            ),
                         ],
                         onSelected: (value) async {
                           if (value == 'delete') {
                              _handleDelete(context, state);
                           } else if (value == 'report') {
                              _showReportDialog(context);
                           }
                         },
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullscreenGallery(
                                images: widget.property.images,
                                initialIndex: _currentImageIndex,
                              ),
                            ),
                          );
                        },
                        child: PageView.builder(
                          itemCount: widget.property.images.length,
                          onPageChanged: (index) => setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) => Hero(
                            tag: 'property_image_$index',
                            child: CachedNetworkImage(
                              imageUrl: widget.property.images[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Image Indicator dots
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: widget.property.images.asMap().entries.map((entry) {
                            return Container(
                              width: 8.0,
                              height: 8.0,
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(
                                  _currentImageIndex == entry.key ? 0.9 : 0.4,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.property.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.property.city}, ${widget.property.country}',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.property.rating}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Icon Grid
                        _buildSectionHeader('О жилье'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCompactInfo(Icons.bed_outlined, '${widget.property.bedrooms}', 'Спальни'),
                            _buildCompactInfo(Icons.bathtub_outlined, '${widget.property.bathrooms}', 'Ванные'),
                            _buildCompactInfo(Icons.people_outline, '${widget.property.guests}', 'Гости'),
                            _buildCompactInfo(Icons.square_foot, '${widget.property.area ?? 0}', 'м²'),
                          ],
                        ),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Описание'),
                        const SizedBox(height: 12),
                        Text(
                          widget.property.description,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            height: 1.7,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Удобства'),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.property.amenities.map((amenity) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                amenity,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 32),
                        Container(
                          key: _calendarKey,
                          child: _buildSectionHeader('Календарь'),
                        ),
                        const SizedBox(height: 16),
                        _buildCalendarSection(state),

                        const SizedBox(height: 32),
                        _buildMapSection(),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Отзывы${_reviewCount > 0 ? ' ($_reviewCount)' : ''}'),
                        if (_averageRating > 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'из 5',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (state.userId != null) // Only allow reviews if logged in
                           Padding(
                             padding: const EdgeInsets.only(bottom: 16.0),
                             child: OutlinedButton(
                               onPressed: () => _showReviewDialog(context),
                               style: OutlinedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                 side: const BorderSide(color: Colors.black),
                                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)
                               ),
                               child: Text('Написать отзыв', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                             ),
                           ),
                        _buildReviewsSection(),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Хозяин'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.black12,
                                    child: Text(
                                      widget.property.authorName.isNotEmpty ? widget.property.authorName[0].toUpperCase() : '?',
                                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.property.authorName,
                                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          'На StayNest с 2026',
                                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                          builder: (context) => Padding(
                                            padding: const EdgeInsets.all(32.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Номер телефона', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                                                const SizedBox(height: 16),
                                                Text(widget.property.authorPhone, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black)),
                                                const SizedBox(height: 32),
                                                SizedBox(
                                                  width: double.infinity,
                                                  height: 56,
                                                  child: ElevatedButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                                    child: Text('Закрыть', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.phone_outlined, size: 20),
                                      label: const Text('Позвонить'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        foregroundColor: Colors.black,
                                        side: const BorderSide(color: Colors.black87),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatDetailPage(
                                              userId: widget.property.authorId,
                                              userName: widget.property.authorName,
                                              propertyId: widget.property.id,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.message_outlined, size: 20),
                                      label: const Text('Написать'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),


                        const SizedBox(height: 140), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Dynamic Booking Toolbar with Price Breakdown
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedStartDay != null) ...[
                    Builder(builder: (context) {
                      final start = _selectedStartDay!;
                      final end = _selectedEndDay ?? _selectedStartDay!;
                      final daysCount = end.difference(start).inDays + 1;
                      
                      double total = 0;
                      int discountDays = 0;
                      for (int i = 0; i < daysCount; i++) {
                        final date = start.add(Duration(days: i));
                        final dateStr = DateFormat('yyyy-MM-dd').format(date);
                        final dayPrice = (_calendarData[dateStr]?['price'] != null)
                            ? (_calendarData[dateStr]['price'] as num).toDouble()
                            : widget.property.price;
                        total += dayPrice;
                        if (dayPrice < widget.property.price) discountDays++;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$daysCount ${daysCount == 1 ? 'ночь' : (daysCount < 5 ? 'ночи' : 'ночей')}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey[600]),
                                ),
                                if (discountDays > 0)
                                  Text(
                                    'Выгода: ${(widget.property.price * daysCount - total).toStringAsFixed(0)} ₸',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.green[600], fontWeight: FontWeight.w700),
                                  ),
                              ],
                            ),
                            Text(
                              state.getFormattedPrice(total),
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  Row(
                    children: [
                      if (_selectedStartDay == null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.getFormattedPrice(widget.property.price),
                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              ),
                              Text(
                                widget.property.rentType == 'DAILY' ? 'за сутки' : 'за месяц',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: _selectedStartDay == null ? 1 : 2,
                        child: ElevatedButton(
                          onPressed: _isBooking ? null : _handleBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isBooking
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                                  _selectedStartDay == null ? 'Выбрать даты' : 'Забронировать',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
    );
  }

  Widget _buildCompactInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Icon(icon, color: Colors.black, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCalendarSection(AppState state) {
    if (_isLoadingCalendar) {
       return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Colors.black)));
    }
    return Column(
      children: [
         _buildMonthPicker(),
         Container(
           padding: const EdgeInsets.symmetric(horizontal: 16),
           height: 360, // Fixed height for calendar
           child: _buildCalendarGrid(state),
         ),
         _buildLegend(),
      ],
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMonthNavButton(Icons.chevron_left, () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1))),
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay).toUpperCase(),
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1, color: Colors.black),
          ),
          _buildMonthNavButton(Icons.chevron_right, () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1))),
        ],
      ),
    );
  }

   Widget _buildMonthNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }

  Widget _buildCalendarGrid(AppState state) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday - 1;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8, // Slightly taller cells
      ),
      itemCount: 7 + weekdayOffset + daysInMonth,
      itemBuilder: (context, index) {
          if (index < 7) {
            final weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
            return Center(
              child: Text(
                weekdays[index],
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w700),
              ),
            );
          }
          
          final dayIndex = index - 7 - weekdayOffset;
          if (dayIndex < 0 || dayIndex >= daysInMonth) return const SizedBox();

          final currentDay = DateTime(_focusedDay.year, _focusedDay.month, dayIndex + 1);
          final dateStr = DateFormat('yyyy-MM-dd').format(currentDay);
          final dayData = _calendarData[dateStr];
          
          bool isBlocked = dayData?['isBlocked'] ?? false;
          double? customPrice = dayData?['price'] != null ? (dayData?['price'] as num).toDouble() : null;

          bool isBooked = false;
          for (var b in _existingBookings) {
            final start = DateTime.parse(b['startDate']).toLocal();
            final end = DateTime.parse(b['endDate']).toLocal();
            if ((currentDay.isAfter(start) || DateUtils.isSameDay(currentDay, start)) && 
                (currentDay.isBefore(end) || DateUtils.isSameDay(currentDay, end))) {
              isBooked = true;
              break;
            }
          }

          return _buildDayCell(currentDay, isBooked, isBlocked, customPrice, state);
      },
    );
  }

  Widget _buildDayCell(DateTime day, bool isBooked, bool isBlocked, double? customPrice, AppState state) {
    Color bgColor = Colors.white;
    Color textColor = Colors.black;
    Border? border;
    
    // Logic for selected
    bool isSelected = false;
    bool isRange = false;

    if (_selectedStartDay != null) {
      if (DateUtils.isSameDay(day, _selectedStartDay)) isSelected = true;
      else if (_selectedEndDay != null) {
         if (DateUtils.isSameDay(day, _selectedEndDay)) isSelected = true;
         else if (day.isAfter(_selectedStartDay!) && day.isBefore(_selectedEndDay!)) isRange = true;
      }
    }

    if (isBooked) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[900]!;
      border = Border.all(color: Colors.orange[200]!);
    } else if (isBlocked) {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey[400]!;
    } else if (isSelected) {
      bgColor = Colors.black;
      textColor = Colors.white;
    } else if (isRange) {
      bgColor = Colors.grey[200]!;
    } else if (customPrice != null) {
      bgColor = Colors.blue[50]!;
      textColor = Colors.blue[900]!;
      border = Border.all(color: Colors.blue[200]!);
    }

    return GestureDetector(
      onTap: (isBooked || isBlocked) ? null : () => _onDaySelected(day),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: border ?? (isSelected ? null : Border.all(color: Colors.grey[200]!)),
          boxShadow: [
            if (!isBlocked && !isBooked && !isRange && !isSelected)
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, 
                fontSize: 16, 
                color: textColor
              ),
            ),
            const SizedBox(height: 1),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: isBooked
                  ? const Text('ЗАНЯТО', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.orange))
                  : isBlocked
                    ? const Icon(Icons.block, size: 10, color: Colors.grey)
                    : Text(
                        state.getFormattedPrice(customPrice ?? widget.property.price),
                        style: GoogleFonts.inter(
                          fontSize: 7, 
                          color: isSelected ? Colors.white70 : (customPrice != null ? Colors.blue[700] : Colors.grey[600]), 
                          fontWeight: FontWeight.w600
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildLegendItem(Colors.orange[50]!, Colors.orange[900]!, 'Занято'),
          _buildLegendItem(Colors.blue[50]!, Colors.blue[900]!, 'Скидка'),
          _buildLegendItem(Colors.black, Colors.white, 'Выбрано'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, Color textColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16, height: 16, 
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[200]!)),
        ),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMapSection() {
    if (widget.property.latitude == null || widget.property.longitude == null) {
      return const SizedBox.shrink();
    }
    
    final point = latLng.LatLng(widget.property.latitude!, widget.property.longitude!);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Местоположение'),
        const SizedBox(height: 16),
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
              // Map background
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
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
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 50,
                            height: 50,
                            point: point,
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 600),
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
              
              // Gradient overlay at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Location info card
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
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_city, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.property.city,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.property.country,
                              style: GoogleFonts.inter(
                                fontSize: 12,
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
              
              // Zoom controls
              Positioned(
                right: 16,
                bottom: 16,
                child: Column(
                  children: [
                    _buildMapButton(Icons.add, () {
                      // Zoom in functionality would go here
                    }),
                    const SizedBox(height: 8),
                    _buildMapButton(Icons.remove, () {
                      // Zoom out functionality would go here
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final url = 'https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}';
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Не удалось открыть карты', style: GoogleFonts.inter()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: $e', style: GoogleFonts.inter()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.navigation, size: 20),
            label: Text('Открыть в Google Maps', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (_isLoadingReviews) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Пока нет отзывов',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Будьте первым, кто оставит отзыв!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _reviews.map((review) => ReviewCard(review: review)).toList(),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: Colors.black),
          ),
        ),
      ),
    );
  }
}
