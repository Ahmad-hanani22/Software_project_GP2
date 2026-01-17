import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_page.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/landlord_dashboard_screen.dart';
import 'utils/app_theme_settings.dart';
import 'utils/app_localizations.dart';
import 'services/firebase_notification_service.dart';

// ✅ Global Navigator Key لعرض SnackBar/Alert من أي مكان
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- 🎨 Premium Color Palette (نفس ألوان الصفحة الرئيسية) ---
const Color _primaryColor = Color(0xFF00695C); // Deep Teal (زمردي فخم)
const Color _secondaryColor = Color(0xFFFFA000); // Amber/Gold (للأزرار المميزة)
const Color _lightBackground = Color(0xFFF8F9FA); // Off-White (عصري)
const Color _darkBackground = Color(0xFF121212); // Pure Dark

// =======================================================
// 🚀 main (نفسك + Firebase initialization فقط)
// =======================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ تهيئة Firebase مع options للويب والموبايل
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ❗ لا Background handler هنا
  await FirebaseNotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppThemeSettings()),
        ChangeNotifierProvider(create: (_) => AppLocalizationsSettings()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // --- ☀️ Light Theme ---
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        secondary: _secondaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _lightBackground,

      // AppBar Design
      appBarTheme: const AppBarTheme(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineSmall:
            TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold),
        titleMedium:
            TextStyle(color: Color(0xFF37474F), fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Color(0xFF455A64)),
      ),

      // Card Design
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _secondaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- 🌙 Dark Theme ---
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        secondary: _secondaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B252A),
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appThemeSettings = Provider.of<AppThemeSettings>(context);
    final appLocalizations = Provider.of<AppLocalizationsSettings>(context);

    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ إضافة Navigator Key
      title: 'SHAQATI',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: appThemeSettings.themeMode,
      locale: appLocalizations.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],
      home: const HomePage(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/admin-dashboard': (_) => const AdminDashboardScreen(),
        '/landlord-dashboard': (_) => const LandlordDashboardScreen(),
      },
    );
  }
}
