import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/change_notifier_provider.dart';
import 'providers/app_state.dart';
import 'pages/login_page.dart';
import 'pages/splash_page.dart';
import 'utils/cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Clear image cache on startup to fix localhost URLs
  CacheManager.clearMemoryCache();
  
  runApp(const StayNestApp());
}

class StayNestApp extends StatelessWidget {
  const StayNestApp({Key? key}) : super(key: key);

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: () => AppState(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'StayNest',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.black,
            primary: Colors.black,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          fontFamily: GoogleFonts.inter().fontFamily,
          textTheme: GoogleFonts.interTextTheme(
            Theme.of(context).textTheme,
          ),
          scaffoldBackgroundColor: const Color(0xFFFEFEFE),
          primaryColor: Colors.black,
          dividerTheme: DividerThemeData(color: Colors.grey[200], thickness: 0.5),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: const IconThemeData(color: Colors.black, size: 20),
            titleTextStyle: GoogleFonts.inter(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const SplashPage(),
      ),
    );
  }
}
