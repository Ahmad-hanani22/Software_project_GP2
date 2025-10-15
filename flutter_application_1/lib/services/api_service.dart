import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// ✅ تأكد من صحة هذا المسار واسم مشروعك
import 'package:flutter_application_1/constants.dart' as AppConstants;

class ApiService {
  /* ===============================
   🟢 Register
  =============================== */
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

  /* ===============================
   🟣 Login
  =============================== */
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

  /* ===============================
   👤 Get current user (decoded from token)
  =============================== */
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

  /* ===============================
   🧭 Get Admin Dashboard Data
  =============================== */
  static Future<(bool, dynamic)> getAdminDashboard() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admin-dashboard');
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

  /* ===============================
   🔒 Logout
  =============================== */
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
  }

  /* ===============================
   🟡 Helpers
  =============================== */
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
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
