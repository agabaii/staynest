import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/app_state.dart';
import '../widgets/change_notifier_provider.dart';
import 'host_dashboard_page.dart';
import 'all_properties_page.dart';
import 'bookings_page.dart';
import 'login_page.dart';
import 'security_page.dart';
import 'support_page.dart';
import 'admin_panel_page.dart';
import '../config/api_config.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = ChangeNotifierProvider.of<AppState>(context);
    if (!isEditing) {
      nameController.text = state.userName;
      emailController.text = state.userEmail;
      phoneController.text = state.userPhone;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            expandedHeight: 0,
            floating: false,
            pinned: true,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            centerTitle: false,
            title: Text(
              'Профиль',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                onPressed: () async {
                  if (isEditing) {
                    await state.updateProfile(
                      name: nameController.text,
                      phone: phoneController.text,
                      avatarPath: _imageFile?.path,
                    );
                    setState(() => _imageFile = null);
                  }
                  setState(() => isEditing = !isEditing);
                },
                  child: Text(
                    isEditing ? 'Готово' : 'Изменить',
                    style: GoogleFonts.inter(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Avatar Section
                  GestureDetector(
                    onTap: isEditing ? () async {
                      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() => _imageFile = File(pickedFile.path));
                      }
                    } : null,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _imageFile != null 
                                ? FileImage(_imageFile!) as ImageProvider
                                : (state.userAvatar != null 
                                    ? NetworkImage('${ApiConfig.getBaseUrl()}${state.userAvatar}') as ImageProvider
                                    : null),
                              child: (state.userAvatar == null && _imageFile == null) 
                                ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                : null,
                            ),
                          ),
                          if (isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.userName,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Подтвержденный аккаунт',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info Cards
                  _buildSectionTitle('Личная информация'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSettingsItem(Icons.person_outline, 'Имя', nameController, isEditing),
                        _buildDivider(),
                        _buildSettingsItem(Icons.email_outlined, 'Email', emailController, false), // Email обычно не меняется напрямую
                        _buildDivider(),
                        _buildSettingsItem(Icons.phone_outlined, 'Телефон', phoneController, isEditing),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle('Управление'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSimpleListItem(Icons.dashboard_outlined, 'Панель хозяина', onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const HostDashboardPage()));
                        }),
                        if (state.isAdmin) ...[
                          _buildDivider(),
                          _buildSimpleListItem(Icons.admin_panel_settings_outlined, 'Админ-панель', onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelPage()));
                          }),
                        ],
                        _buildDivider(),
                        _buildSimpleListItem(Icons.list_alt_outlined, 'Мои объявления', onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const AllPropertiesPage(onlyMyProperties: true)));
                        }),
                        _buildDivider(),
                        _buildSimpleListItem(Icons.card_travel_outlined, 'Мои поездки', onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingsPage()));
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle('Безопасность и настройки'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSimpleListItem(Icons.security_outlined, 'Пароль и безопасность', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityPage()));
                        }),
                        _buildDivider(),
                        _buildSimpleListItem(Icons.help_outline, 'Помощь и поддержка', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage()));
                        }),
                        _buildDivider(),
                        _buildSimpleListItem(
                          Icons.language_outlined, 
                          'Язык: ${state.language}',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                              builder: (context) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Text(
                                          'Выберите язык',
                                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      _buildLanguageOption(context, state, 'RU', 'Русский'),
                                      _buildLanguageOption(context, state, 'KZ', 'Қазақша'),
                                      _buildLanguageOption(context, state, 'EN', 'English'),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                );
                              }
                            );
                          }
                        ),
                        _buildDivider(),
                        _buildSimpleListItem(
                          Icons.currency_exchange, 
                          'Валюта: ${state.selectedCurrency}',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                              builder: (context) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Text(
                                          'Выберите валюту',
                                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      _buildCurrencyOption(context, state, 'RUB', 'Российский рубль (₽)'),
                                      _buildCurrencyOption(context, state, 'KZT', 'Казахстанский тенге (₸)'),
                                      _buildCurrencyOption(context, state, 'USD', 'Доллар США (\$)'),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                );
                              }
                            );
                          }
                        ),
                        _buildDivider(),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.logout, color: Colors.red[600]),
                          ),
                          title: Text(
                            'Выйти',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.red[600],
                            ),
                          ),
                          onTap: () async {
                            await state.logout();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 60, color: Colors.grey[100]);
  }

  Widget _buildSettingsItem(IconData icon, String label, TextEditingController controller, bool isEditing, {int maxLines = 1}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.blue[700]),
      ),
      title: isEditing 
          ? TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  controller.text, 
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }

  Widget _buildSimpleListItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildLanguageOption(BuildContext context, AppState state, String code, String name) {
    bool isSelected = state.language == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.black) : null,
      onTap: () {
        state.setLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCurrencyOption(BuildContext context, AppState state, String code, String name) {
    bool isSelected = state.selectedCurrency == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.black) : null,
      onTap: () {
        state.setCurrency(code);
        Navigator.pop(context);
      },
    );
  }
}
