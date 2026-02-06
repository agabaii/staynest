import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await _notificationService.getNotifications();
    setState(() {
      _notifications = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Уведомления', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () async {
              await _notificationService.markAllAsRead();
              _loadNotifications();
            },
            icon: const Icon(Icons.done_all, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : _notifications.isEmpty
          ? Center(child: Text('Нет уведомлений', style: GoogleFonts.inter()))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) => _buildNotificationCard(_notifications[index]),
            ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'BOOKING':
        icon = Icons.calendar_today;
        color = Colors.blue;
        break;
      case 'MESSAGE':
        icon = Icons.message;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[50]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: notification.isRead ? Colors.grey[200]! : Colors.blue[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.content, style: GoogleFonts.inter(fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd.MM HH:mm').format(notification.createdAt.toLocal()),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
