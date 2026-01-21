import 'package:flutter/material.dart';

/// ثيم موحد لصفحات المستأجر (Tenant) في شقتي
class TenantTheme {
  TenantTheme._();

  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color accent = Color(0xFF00BFA5);
  static const Color accentOrange = Color(0xFFFF8A65);
  static const Color scaffoldBg = Color(0xFFF5F7FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A237E);
  static const Color textSecondary = Color(0xFF5C6BC0);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFC62828);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ];

  static const double radiusMd = 14.0;
  static const double radiusLg = 18.0;

  static Widget shaqatiLogo({double iconSize = 26, double textSize = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.home_work_rounded, color: Colors.white, size: iconSize),
        const SizedBox(width: 8),
        Text("SHAQATI",
            style: TextStyle(
                color: Colors.white,
                fontSize: textSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8)),
      ],
    );
  }

  /// AppBar موحد بصفحات المستأجر: تدرج، عنوان، زر رجوع اختياري
  static PreferredSizeWidget appBar({
    required String title,
    List<Widget>? actions,
    VoidCallback? onBack,
    Widget? leading,
  }) {
    return AppBar(
      leading: leading ??
          (onBack != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                )
              : null),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: headerGradient)),
      backgroundColor: primary,
      elevation: 0,
      foregroundColor: Colors.white,
      actions: actions,
    );
  }
}
