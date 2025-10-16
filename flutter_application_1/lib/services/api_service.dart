// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/constants.dart' as AppConstants;

// ---------------------------------------------
// System Setting Data Model (محدث)
// ---------------------------------------------
class SystemSetting {
  final String key;
  dynamic value; // Can be String, bool, int, etc.
  final String type; // 'text', 'boolean', 'dropdown', 'number'
  final String label;
  final List<String>? options; // For dropdowns
  final String category; // جديد: لتجميع الإعدادات
  final String? description; // جديد: لوصف الإعداد

  SystemSetting({
    required this.key,
    required this.value,
    required this.type,
    required this.label,
    this.options,
    this.category = 'General', // قيمة افتراضية
    this.description,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) {
    return SystemSetting(
      key: json['key'],
      value: json['value'],
      type: json['type'],
      label: json['label'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      category: json['category'] ?? 'General', // قراءة الفئة
      description: json['description'], // قراءة الوصف
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'type': type,
      'label': label,
      if (options != null) 'options': options,
      'category': category,
      if (description != null) 'description': description,
    };
  }
}

class ApiService {
  // ================= Register/Login/GetMe كما عندك =================

  static Future<(bool, String)> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/register');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (res.statusCode == 201 || res.statusCode == 200) {
      return (true, 'Registered');
    } else {
      return (false, _extractMessage(res.body));
    }
  }

  static Future<(bool, String, String?)> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final token = data['token'];
      final String? role = data['role']?.toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      if (role != null) {
        await prefs.setString('role', role);
      } else {
        await prefs.remove('role');
      }

      return (true, 'Logged in', role);
    } else {
      return (false, _extractMessage(res.body), null);
    }
  }

  static Future<(bool, dynamic)> getMe() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/test/check');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (true, data['user']);
      } else {
        return (false, _extractMessage(res.body));
      }
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Dashboard (تأكد من endpoint الصحيح عندك) =================
  static Future<(bool, dynamic)> getAdminDashboard() async {
    try {
      final token = await getToken();
      final url = Uri.parse(
        '${AppConstants.baseUrl}/admin/dashboard',
      ); // تأكد من الراوت
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body));
      } else {
        return (false, _extractMessage(res.body));
      }
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Users (Admin) =================

  static Future<(bool, dynamic)> getAllUsers() async {
    try {
      final token = await getToken();
      if (token == null) return (false, 'No token found');

      final url = Uri.parse('${AppConstants.baseUrl}/admins/users');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addUser({
    required String name,
    required String email,
    required String role,
    required String password,
    String? phone,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admins/users');
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'name': name,
          'email': email,
          'role': role,
          'password': password,
          if (phone != null) 'phone': phone,
        }),
      );
      if (res.statusCode == 201) return (true, 'User created');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateUser({
    required String id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? password, // اختياري
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admins/users/$id');
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (role != null) body['role'] = role;
      if (phone != null) body['phone'] = phone;
      if (password != null && password.trim().isNotEmpty) {
        body['password'] = password.trim();
      }

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) return (true, 'User updated');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteUser(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admins/users/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, 'User deleted');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= System Settings (Admin) (محدث) =================

  static Future<(bool, List<SystemSetting>)> getSystemSettings() async {
    try {
      final token = await getToken();
      if (token == null) return (false, <SystemSetting>[]);

      final url = Uri.parse('${AppConstants.baseUrl}/admin/settings');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(res.body);
        return (true, jsonList.map((e) => SystemSetting.fromJson(e)).toList());
      }
      return (false, <SystemSetting>[]);
    } catch (e) {
      print("Error in getSystemSettings: $e");
      return (false, <SystemSetting>[]);
    }
  }

  static Future<(bool, String)> updateSystemSetting(
    String key,
    dynamic value,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return (false, 'No token found');

      final url = Uri.parse('${AppConstants.baseUrl}/admin/settings/$key');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'value': value}),
      );
      if (res.statusCode == 200) return (true, 'Setting updated successfully');
      return (false, _extractMessage(res.body));
    } catch (e) {
      print("Error in updateSystemSetting: $e");
      return (false, e.toString());
    }
  }

  // ================= Helpers =================
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ======================================================
  // 🔒 Logout Function (تسجيل الخروج من التطبيق)
  // ======================================================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('userName');
    // عند تسجيل الخروج، تأكد من إعادة تعيين الوضع الليلي إلى الافتراضي أو حسب ما تراه مناسبًا
    // على سبيل المثال:
    // await prefs.setBool('dark_mode_enabled', false);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Map<String, String> _authHeaders(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static String _extractMessage(String body) {
    try {
      final map = jsonDecode(body);
      return map['message']?.toString() ?? 'Request failed';
    } catch (_) {
      return 'Request failed';
    }
  }
}
