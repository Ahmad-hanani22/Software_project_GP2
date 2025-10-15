import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_page.dart';
import 'screens/admin_dashboard_screen.dart'; // ✅ استيراد شاشة الأدمن
import 'screens/landlord_dashboard_screen.dart'; // ✅ استيراد شاشة المالك

void main() => runApp(const MyApp());


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHAQATI Real Estate App', // ✅ تعديل عنوان التطبيق
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32),
      ),
      home: const HomePage(), // 👈 نبدأ بالهوم
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/admin-dashboard': (_) => const AdminDashboardScreen(), // ✅ مسار جديد
        '/landlord-dashboard': (_) => const LandlordDashboardScreen(), // ✅ مسار جديد
      },
    );
  }
}