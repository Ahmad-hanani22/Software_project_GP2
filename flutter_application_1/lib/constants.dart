import 'package:flutter/foundation.dart';

class AppConstants {
  // 🔥 Backend مرفوع على Render (HTTPS)
  static const String _renderBaseUrl =
      "https://shaqati-backend.onrender.com/api";

  // 🏠 Local Backend (Development)
  static const String _localBaseUrl = "http://localhost:3000/api";

  /// 🔹 Base URL موحد لكل المنصات
  /// Web / Android / iOS
  static String get baseUrl {
    if (kIsWeb) {
      return _localBaseUrl;
    }
    // For Android Emulator use 10.0.2.2 instead of localhost
    return "http://10.0.2.2:3000/api";
    // return _renderBaseUrl;
  }
}
