// lib/utils/app_theme_settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeSettings with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // الافتراضي هو الوضع الفاتح
  ThemeMode get themeMode => _themeMode;

  // مفتاح حفظ الوضع الليلي في SharedPreferences (يتطابق مع key في SystemSetting)
  static const String _darkModeKey = 'dark_mode_enabled';

  AppThemeSettings() {
    _loadThemeMode(); // تحميل الوضع عند إنشاء الكائن
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    // جلب القيمة من SharedPreferences أو من إعدادات النظام
    // (يجب أن يتم تحديث SharedPreferences عندما تتغير القيمة من AdminSystemSettingsScreen)
    final bool isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // إعلام المستمعين بالوضع الحالي
  }

  Future<void> setThemeMode(bool isDarkMode) async {
    if ((isDarkMode && _themeMode == ThemeMode.dark) ||
        (!isDarkMode && _themeMode == ThemeMode.light)) {
      return; // لا يوجد تغيير
    }

    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode); // حفظ التفضيل محليًا
    notifyListeners(); // إعلام المستمعين بالتغيير
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;
}
