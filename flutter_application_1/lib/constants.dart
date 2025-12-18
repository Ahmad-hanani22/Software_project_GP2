import 'package:flutter/foundation.dart';

class AppConstants {
  // 🔥 Backend مرفوع على Render (HTTPS)
  static const String _renderBaseUrl =
      "https://shaqati-backend.onrender.com/api";

  /// 🔹 Base URL موحد لكل المنصات
  /// Web / Android / iOS
  static String get baseUrl {
    return _renderBaseUrl;
  }
}
