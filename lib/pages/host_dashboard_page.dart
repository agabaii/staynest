import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/property.dart';
import '../providers/app_state.dart';
import '../services/booking_service.dart';
import '../widgets/change_notifier_provider.dart';
import 'add_property_page.dart';
import 'edit_property_page.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'property_calendar_page.dart';
import '../config/api_config.dart';

class HostDashboardPage extends StatefulWidget {
  const HostDashboardPage({Key? key}) : super(key: key);

  @override
  State<HostDashboardPage> createState() => _HostDashboardPageState();
}

class _HostDashboardPageState extends State<HostDashboardPage> {
  final BookingService _bookingService = BookingService();
  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _bookingService.getOwnerBookings();
    setState(() {
      _bookings = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    final myProperties = state.properties.where((p) => p.authorId == state.userId).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Панель управления', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildStats(state, myProperties),
              const SizedBox(height: 32),
              _buildSectionTitle('Заявки на бронирование'),
              const SizedBox(height: 16),
              if (_bookings.where((b) => b.status == 'PENDING').isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Нет новых заявок', style: GoogleFonts.inter(color: Colors.grey)),
                ))
              else
                ..._bookings.where((b) => b.status == 'PENDING').map((b) => _buildBookingRequestCard(b)).toList(),
              const SizedBox(height: 32),
              _buildSectionTitle('Мои объекты'),
              const SizedBox(height: 16),
              ...myProperties.map((p) => _buildMyPropertyCard(p, state)).toList(),
              const SizedBox(height: 100),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPropertyPage())),
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Добавить', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStats(AppState state, List<Property> properties) {
    final activeBookings = _bookings.where((b) => b.status == 'CONFIRMED' || b.status == 'AWAITING_PAYMENT').length;
    double totalIncome = 0;
    for (var b in _bookings) { if (b.status == 'CONFIRMED') totalIncome += b.totalPrice; }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Объекты', '${properties.length}', Icons.home, Colors.black87),
        _buildStatCard('Активные', '$activeBookings', Icons.calendar_today, Colors.green),
        _buildStatCard('Доход', state.getFormattedPrice(totalIncome), Icons.money, Colors.orange),
        _buildStatCard('Рейтинг', '5.0', Icons.star, Colors.amber),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800));
  }

  Widget _buildBookingRequestCard(Booking booking) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.black12, child: Text(booking.renterName?[0].toUpperCase() ?? '?')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.renterName ?? 'Арендатор', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    Text(booking.propertyTitle ?? 'Объект', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text('${DateFormat('dd.MM').format(booking.startDate.toLocal())} - ${DateFormat('dd.MM.yyyy').format(booking.endDate.toLocal())}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(state.getFormattedPrice(booking.totalPrice), style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(booking.id, 'AWAITING_PAYMENT'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Принять запрос', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(booking.id, 'CANCELLED'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Отклонить', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPropertyCard(Property p, AppState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyCalendarPage(property: p)));
        },
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.images.isNotEmpty 
              ? CachedNetworkImage(imageUrl: p.images[0].startsWith('http') ? p.images[0] : '${ApiConfig.getBaseUrl()}${p.images[0]}', width: 60, height: 60, fit: BoxFit.cover)
              : Container(width: 60, height: 60, color: Colors.grey[200]),
          ),
          title: Text(p.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${p.city}, ${state.getFormattedPrice(p.price)}', style: GoogleFonts.inter(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.black),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditPropertyPage(property: p)),
                  );
                  if (result == true) _loadData();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _deleteProperty(p.id),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, size: 18),
                  Text('Кал.', style: GoogleFonts.inter(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProperty(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить объявление?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Это действие нельзя будет отменить.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Отмена', style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Удалить', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w800))),
        ],
      ),
    );

    if (confirm == true) {
      final token = await AuthService().getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/properties/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final state = ChangeNotifierProvider.of<AppState>(context);
        state.fetchProperties();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявление удалено')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка при удалении')));
      }
    }
  }

  Widget _buildStatusBadge(String status) {
     Color color = Colors.grey;
     String text = status;
    if (status == 'PENDING') { color = Colors.orange; text = 'Ожидает'; }
    if (status == 'AWAITING_PAYMENT') { color = Colors.black87; text = 'Одобрено. Оплата...'; }
    if (status == 'CONFIRMED') { color = Colors.green; text = 'Оплачено'; }
    if (status == 'CANCELLED') { color = Colors.red; text = 'Отклонено'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Future<void> _updateStatus(int id, String status) async {
    print('=== UPDATE STATUS ===');
    print('Booking ID: $id');
    print('New status: $status');
    final success = await _bookingService.updateStatus(id, status);
    print('Success: $success');
    if (success) {
      print('Reloading data...');
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Статус обновлен: $status'), backgroundColor: Colors.green),
      );
    } else {
      print('Failed to update status');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка обновления статуса'), backgroundColor: Colors.red),
      );
    }
  }
}
