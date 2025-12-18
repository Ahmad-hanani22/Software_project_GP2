// lib/utils/app_localizations.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'SHAQATI',
      'login': 'Login',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'name': 'Name',
      'phone': 'Phone',
      'logout': 'Logout',
      'dashboard': 'Dashboard',
      'properties': 'Properties',
      'contracts': 'Contracts',
      'payments': 'Payments',
      'maintenance': 'Maintenance',
      'complaints': 'Complaints',
      'users': 'Users',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'chat': 'Chat',
      'reviews': 'Reviews',
      'search': 'Search',
      'filter': 'Filter',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'update': 'Update',
      'submit': 'Submit',
      'confirm': 'Confirm',
      'yes': 'Yes',
      'no': 'No',
      'close': 'Close',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'info': 'Info',
    },
    'ar': {
      'appTitle': 'شقتي',
      'login': 'تسجيل الدخول',
      'register': 'التسجيل',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'name': 'الاسم',
      'phone': 'الهاتف',
      'logout': 'تسجيل الخروج',
      'dashboard': 'لوحة التحكم',
      'properties': 'العقارات',
      'contracts': 'العقود',
      'payments': 'الدفعات',
      'maintenance': 'الصيانة',
      'complaints': 'الشكاوى',
      'users': 'المستخدمون',
      'settings': 'الإعدادات',
      'notifications': 'الإشعارات',
      'chat': 'الدردشة',
      'reviews': 'التقييمات',
      'search': 'بحث',
      'filter': 'فلترة',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
      'add': 'إضافة',
      'update': 'تحديث',
      'submit': 'إرسال',
      'confirm': 'تأكيد',
      'yes': 'نعم',
      'no': 'لا',
      'close': 'إغلاق',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'warning': 'تحذير',
      'info': 'معلومات',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class AppLocalizationsSettings with ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  static const String _localeKey = 'app_locale';

  AppLocalizationsSettings() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey) ?? 'en';
    _locale = Locale(localeCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }
}

