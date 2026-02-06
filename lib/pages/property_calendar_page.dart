import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/property.dart';
import '../providers/app_state.dart';
import '../widgets/change_notifier_provider.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class PropertyCalendarPage extends StatefulWidget {
  final Property property;
  const PropertyCalendarPage({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyCalendarPage> createState() => _PropertyCalendarPageState();
}

class _PropertyCalendarPageState extends State<PropertyCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  List<dynamic> _bookings = [];
  Map<String, dynamic> _calendarData = {};
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() => _isLoading = true);
    final token = await _authService.getToken();
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('${ApiConfig.getBaseUrl()}/api/properties/${widget.property.id}/calendar'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse('${ApiConfig.getBaseUrl()}/api/properties/${widget.property.id}/bookings'),
          headers: {'Authorization': 'Bearer $token'},
        ),
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
        _bookings = jsonDecode(responses[1].body);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDay(DateTime date, {double? price, bool? isBlocked}) async {
    final token = await _authService.getToken();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/properties/${widget.property.id}/calendar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'date': dateStr,
          'price': price,
          'isBlocked': isBlocked,
        }),
      );
      if (response.statusCode == 200) {
        _loadCalendar();
      }
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Календарь цен',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 20),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Color(0xFF2D2D2D)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.black)))
          else ...[
            SliverToBoxAdapter(child: _buildMonthPicker()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildCalendarGrid(state),
            ),
            SliverToBoxAdapter(child: const SizedBox(height: 32)),
            SliverToBoxAdapter(child: _buildLegend()),
            SliverToBoxAdapter(child: const SizedBox(height: 100)),
          ]
        ],
      ),
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

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
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
          for (var b in _bookings) {
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
        childCount: 7 + weekdayOffset + daysInMonth,
      ),
    );
  }

  Widget _buildDayCell(DateTime day, bool isBooked, bool isBlocked, double? customPrice, AppState state) {
    Color bgColor = Colors.white;
    Color textColor = Colors.black;
    Border? border;
    
    if (isBooked) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[900]!;
      border = Border.all(color: Colors.orange[200]!);
    } else if (isBlocked) {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey[400]!;
    } else if (customPrice != null) {
      bgColor = Colors.blue[50]!;
      textColor = Colors.blue[900]!;
      border = Border.all(color: Colors.blue[200]!);
    }

    return GestureDetector(
      onTap: isBooked ? null : () => _showDayOptions(day, customPrice, isBlocked),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: border ?? Border.all(color: Colors.grey[200]!),
          boxShadow: [
            if (!isBlocked && !isBooked)
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 2),
            if (isBooked)
              Text('ЗАНЯТО', style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.orange))
            else if (isBlocked)
               const Icon(Icons.block, size: 10, color: Colors.grey)
            else
              Text(
                state.getFormattedPrice(customPrice ?? widget.property.price),
                style: GoogleFonts.inter(fontSize: 8, color: customPrice != null ? Colors.blue[700] : Colors.grey[600], fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayOptions(DateTime date, double? currentPrice, bool isBlocked) {
    final priceController = TextEditingController(text: currentPrice?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text(DateFormat('dd MMMM yyyy').format(date), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                   Icon(Icons.block, color: isBlocked ? Colors.red : Colors.grey),
                   const SizedBox(width: 16),
                   Expanded(child: Text('Заблокировать день', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                   Switch(
                     value: isBlocked, 
                     activeColor: Colors.black,
                     onChanged: (val) {
                       Navigator.pop(context);
                       _updateDay(date, isBlocked: val);
                     }
                   ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Установить спец. цену', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Базовая цена: ${widget.property.price}',
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.edit_note, color: Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(20),
              ),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                   final price = double.tryParse(priceController.text);
                   Navigator.pop(context);
                   _updateDay(date, price: price, isBlocked: isBlocked);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text('Применить изменения', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ОБОЗНАЧЕНИЯ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildLegendItem(Colors.orange[50]!, Colors.orange[900]!, 'Забронировано'),
          const SizedBox(height: 12),
          _buildLegendItem(Colors.blue[50]!, Colors.blue[900]!, 'Ваша спец. цена'),
          const SizedBox(height: 12),
          _buildLegendItem(Colors.grey[100]!, Colors.grey[400]!, 'Заблокировано'),
          const SizedBox(height: 12),
          _buildLegendItem(Colors.white, Colors.black, 'Доступно (базовая цена)'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, Color textColor, String label) {
    return Row(
      children: [
        Container(
          width: 32, height: 32, 
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
          child: Center(child: Text('12', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: textColor))),
        ),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
