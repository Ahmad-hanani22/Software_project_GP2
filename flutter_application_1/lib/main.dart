import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_page.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/landlord_dashboard_screen.dart';
import 'utils/app_theme_settings.dart';
import 'utils/app_localizations.dart';

// --- 🎨 Premium Color Palette (نفس ألوان الصفحة الرئيسية) ---
const Color _primaryColor = Color(0xFF00695C); // Deep Teal (زمردي فخم)
const Color _secondaryColor = Color(0xFFFFA000); // Amber/Gold (للأزرار المميزة)
const Color _lightBackground = Color(0xFFF8F9FA); // Off-White (عصري)
const Color _darkBackground = Color(0xFF121212); // Pure Dark

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppThemeSettings()),
        ChangeNotifierProvider(create: (context) => AppLocalizationsSettings()),
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
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Input Fields Design (Modern)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
      ),

      // Buttons Design
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      // Floating Action Button
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        secondary: _secondaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B252A), // Darker Teal/Grey
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineSmall:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Colors.white70),
        bodyMedium: TextStyle(color: Colors.grey),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _secondaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _secondaryColor, // Gold looks good on dark
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // استخدام Provider للتحكم بالثيم واللغة
    final appThemeSettings = Provider.of<AppThemeSettings>(context);
    final appLocalizations = Provider.of<AppLocalizationsSettings>(context);

    return MaterialApp(
      title: 'SHAQATI',
      debugShowCheckedModeBanner: false,

      // تطبيق الثيمات
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: appThemeSettings.themeMode,

      // تطبيق اللغات
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

      // الشاشة الرئيسية
      home: const HomePage(),

      // المسارات (تأكد أن أسماء الكلاسات صحيحة)
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/admin-dashboard': (_) => const AdminDashboardScreen(),
        '/landlord-dashboard': (_) => const LandlordDashboardScreen(),
      },
    );
  }
}
