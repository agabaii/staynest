import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../providers/app_state.dart';
import '../services/booking_service.dart';
import '../widgets/change_notifier_provider.dart';
import '../config/api_config.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({Key? key}) : super(key: key);

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final BookingService _bookingService = BookingService();
  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final data = await _bookingService.getMyBookings();
    setState(() {
      _bookings = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Мои поездки', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800)),
          bottom: TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: const [
              Tab(text: 'Активные'),
              Tab(text: 'Прошлые/Отмененные'),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : TabBarView(
              children: [
                _buildList(_bookings.where((b) => b.status != 'CANCELLED' && b.endDate.isAfter(DateTime.now())).toList()),
                _buildList(_bookings.where((b) => b.status == 'CANCELLED' || b.endDate.isBefore(DateTime.now())).toList()),
              ],
            ),
      ),
    );
  }

  Widget _buildList(List<Booking> bookings) {
    if (bookings.isEmpty) {
      return Center(child: Text('Нет бронирований', style: GoogleFonts.inter()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bookings.length,
      itemBuilder: (context, index) => _buildCard(bookings[index]),
    );
  }

  Widget _buildCard(Booking booking) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: booking.propertyImage != null 
              ? CachedNetworkImage(
                  imageUrl: '${ApiConfig.getBaseUrl()}${booking.propertyImage}',
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(height: 150, color: Colors.grey[200]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.propertyTitle ?? 'Жилье',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _buildStatusBadge(booking.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('dd.MM').format(booking.startDate)} - ${DateFormat('dd.MM.yyyy').format(booking.endDate)}',
                      style: GoogleFonts.inter(color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Сумма:', style: GoogleFonts.inter(color: Colors.grey)),
                    Text(
                      state.getFormattedPrice(booking.totalPrice),
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (booking.status == 'AWAITING_PAYMENT')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      onPressed: () => _handlePayment(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Оплатить сейчас'),
                    ),
                  ),
                if (booking.status == 'PENDING' || booking.status == 'CONFIRMED' || booking.status == 'AWAITING_PAYMENT')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton(
                      onPressed: () => _cancelBooking(booking.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Отменить бронирование'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    String text = status;
    if (status == 'PENDING') { color = Colors.orange; text = 'Ожидает ответа'; }
    if (status == 'AWAITING_PAYMENT') { color = Colors.black; text = 'Одобрено. Нужно оплатить'; }
    if (status == 'CONFIRMED') { color = Colors.green; text = 'Подтверждено'; }
    if (status == 'CANCELLED') { color = Colors.red; text = 'Отменено/Отклонено'; }
    if (status == 'REJECTED') { color = Colors.red; text = 'Отклонено'; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Future<void> _handlePayment(Booking booking) async {
    final paid = await _showPaymentSheet(context, booking.totalPrice);
    if (paid) {
      final success = await _bookingService.updateStatus(booking.id, 'CONFIRMED');
      if (success) {
        _loadBookings();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бронирование успешно оплачено!'), backgroundColor: Colors.green));
      }
    }
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

  Future<void> _cancelBooking(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить бронирование?'),
        content: const Text('Вы уверены, что хотите отменить бронирование?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Нет', style: GoogleFonts.inter())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Да, отменить', style: GoogleFonts.inter(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await _bookingService.updateStatus(id, 'CANCELLED');
    if (success) {
      _loadBookings();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бронирование отменено')));
    }
  }
}
