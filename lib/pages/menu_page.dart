import 'package:flutter/material.dart';
import '../widgets/change_notifier_provider.dart';
import '../providers/app_state.dart';
import 'home_page.dart';
import 'all_properties_page.dart';
import 'favorites_page.dart';
import 'bookings_page.dart';
import 'host_dashboard_page.dart';
import 'profile_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Меню'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildMenuItem(
            Icons.home,
            'Главная',
            () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            ),
          ),
          _buildMenuItem(
            Icons.list,
            'Объявления',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllPropertiesPage()),
            ),
          ),
          _buildMenuItem(
            Icons.favorite,
            'Избранное',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesPage()),
            ),
          ),
          _buildMenuItem(
            Icons.book,
            'Мои бронирования',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookingsPage()),
            ),
          ),
          _buildMenuItem(
            Icons.dashboard,
            'Панель хозяина',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HostDashboardPage()),
            ),
          ),
          _buildMenuItem(
            Icons.person,
            'Профиль',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
