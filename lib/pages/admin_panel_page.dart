import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import 'property_detail_page.dart';
import '../models/property.dart';
import '../config/api_config.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  
  List<dynamic> _users = [];
  List<dynamic> _properties = [];
  List<dynamic> _reports = [];
  
  bool _isLoadingUsers = true;
  bool _isLoadingProperties = true;
  bool _isLoadingReports = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUsers();
    _fetchProperties();
    _fetchReports();
  }

  // --- USERS ---
  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/admin/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _toggleBan(int userId) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/admin/users/$userId/toggle-ban'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Статус пользователя изменен')));
      }
    } catch (e) {
      print('Error toggling ban: $e');
    }
  }

  // --- PROPERTIES ---
  Future<void> _fetchProperties() async {
    setState(() => _isLoadingProperties = true);
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/admin/properties'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _properties = jsonDecode(response.body);
          _isLoadingProperties = false;
        });
      }
    } catch (e) {
      print('Error fetching properties: $e');
      setState(() => _isLoadingProperties = false);
    }
  }

  Future<void> _updatePropertyStatus(int id, String status) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/admin/properties/$id/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200) {
        _fetchProperties();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Статус изменен на $status')));
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  // --- REPORTS ---
  Future<void> _fetchReports() async {
    setState(() => _isLoadingReports = true);
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/admin/reports'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _reports = jsonDecode(response.body);
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      print('Error fetching reports: $e');
      setState(() => _isLoadingReports = false);
    }
  }
   Future<void> _resolveReport(int id) async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.getBaseUrl()}/api/admin/reports/$id/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'status': 'RESOLVED'}),
      );
      if (response.statusCode == 200) {
        _fetchReports();
      }
    } catch (e) {
      print('Error resolving report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('Админ-панель', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Пользователи'),
            Tab(text: 'Объявления'),
            Tab(text: 'Жалобы'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersList(),
                _buildPropertiesList(),
                _buildReportsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          _buildStatItem('Пользователи', _users.length.toString(), Icons.people_outline, Colors.black87),
          const SizedBox(width: 12),
          _buildStatItem('Объекты', _properties.length.toString(), Icons.home_work_outlined, Colors.green),
          const SizedBox(width: 12),
          _buildStatItem('Жалобы', _reports.where((r) => r['status'] != 'RESOLVED').length.toString(), Icons.report_outlined, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black)),
            Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoadingUsers) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return const Center(child: Text('Нет пользователей'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isBanned = user['isBanned'] ?? false;
        final role = user['role'];
                
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isBanned ? Colors.grey : (role == 'ADMIN' ? Colors.black : Colors.black54),
              child: Icon(
                role == 'ADMIN' ? Icons.security : Icons.person, 
                color: Colors.white
              ),
            ),
            title: Text(
              user['name'] ?? 'Без имени',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, decoration: isBanned ? TextDecoration.lineThrough : null),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email'], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildBadge(Icons.home, '${user['_count']['properties']} об.'),
                    const SizedBox(width: 8),
                    _buildBadge(Icons.bookmark, '${user['_count']['bookings']} бр.'),
                  ],
                ),
              ],
            ),
            trailing: user['role'] != 'ADMIN' 
              ? IconButton(
                  icon: Icon(isBanned ? Icons.lock_open : Icons.block, color: isBanned ? Colors.green : Colors.red),
                  onPressed: () => _toggleBan(user['id']),
                )
              : null,
          ),
        );
      },
    );
  }

  Widget _buildPropertiesList() {
    if (_isLoadingProperties) return const Center(child: CircularProgressIndicator());
    if (_properties.isEmpty) return const Center(child: Text('Нет объявлений'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _properties.length,
      itemBuilder: (context, index) {
        final p = _properties[index];
        final status = p['status'] ?? 'PENDING';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ExpansionTile(
            title: Text(p['title'] ?? 'Без названия', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            subtitle: Text('${p['author']['name']} • ${p['price']}₸', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            leading: _buildStatusBadge(status),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                       icon: const Icon(Icons.check, color: Colors.green),
                       label: Text('Одобрить', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w700)),
                       onPressed: () => _updatePropertyStatus(p['id'], 'APPROVED'),
                    ),
                    TextButton.icon(
                       icon: const Icon(Icons.close, color: Colors.red),
                       label: Text('Отклонить', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
                       onPressed: () => _updatePropertyStatus(p['id'], 'REJECTED'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.grey),
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyDetailPage(property: Property.fromJson(p))));
                      },
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsList() {
    if (_isLoadingReports) return const Center(child: CircularProgressIndicator());
    if (_reports.isEmpty) return const Center(child: Text('Нет жалоб'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final r = _reports[index];
        final isResolved = r['status'] == 'RESOLVED';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isResolved ? Colors.grey[100] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: ListTile(
            leading: Icon(Icons.report_problem, color: isResolved ? Colors.grey : Colors.red),
            title: Text(r['reason'], style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 if (r['property'] != null) Text('Жалоба на объявление: ${r['property']['title']}', style: GoogleFonts.inter(fontSize: 12)),
                 if (r['user'] != null) Text('Жалоба на польз.: ${r['user']['name']}', style: GoogleFonts.inter(fontSize: 12)),
                 Text('От: ${r['reporter']['name']} • ${r['details'] ?? ''}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ],
            ),
            trailing: !isResolved 
              ? IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  onPressed: () => _resolveReport(r['id']),
                  tooltip: 'Решить',
                ) 
              : const Icon(Icons.check, color: Colors.green),
          ),
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    switch(status) {
      case 'APPROVED': color = Colors.green; icon = Icons.check_circle; break;
      case 'REJECTED': color = Colors.red; icon = Icons.cancel; break;
      default: color = Colors.orange; icon = Icons.access_time_filled;
    }
    return Icon(icon, color: color);
  }
}
