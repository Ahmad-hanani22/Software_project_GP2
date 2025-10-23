// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/constants.dart' as AppConstants;
import 'package:image_picker/image_picker.dart';

// Your SystemSetting class...
class SystemSetting {
  final String key;
  dynamic value;
  final String type, label, category;
  final List<String>? options;
  final String? description;

  SystemSetting({
    required this.key,
    required this.value,
    required this.type,
    required this.label,
    this.options,
    this.category = 'General',
    this.description,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) {
    return SystemSetting(
      key: json['key'],
      value: json['value'],
      type: json['type'],
      label: json['label'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      category: json['category'] ?? 'General',
      description: json['description'],
    );
  }
}

class ApiService {
  // ================= Auth =================

  static Future<(bool, String)> register(
      {required String name,
      required String email,
      required String password}) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/register');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      if (res.statusCode < 300) return (true, 'Registered successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Could not connect to the server.');
    }
  }

  static Future<(bool, String, String?)> login(
      {required String email, required String password}) async {
    final url = Uri.parse('${AppConstants.baseUrl}/auth/login');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];
        final String? role = data['role']?.toString();
        final String? userName = data['name']?.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        if (role != null) await prefs.setString('role', role);
        if (userName != null) await prefs.setString('userName', userName);

        return (true, 'Logged in successfully.', role);
      }
      return (false, _extractMessage(res.body), null);
    } catch (e) {
      return (false, 'Could not connect to the server.', null);
    }
  }

  static Future<(bool, dynamic)> getMe() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/auth/me');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body)['user']);
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Dashboard =================
  static Future<(bool, dynamic)> getAdminDashboard() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admin/dashboard');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Users (Admin) =================
  static Future<(bool, dynamic)> getAllUsers() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admins/users');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addUser(
      {required String name,
      required String email,
      required String role,
      required String password,
      String? phone}) async {
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
      if (res.statusCode == 201) return (true, 'User created successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateUser(
      {required String id,
      String? name,
      String? email,
      String? role,
      String? phone,
      String? password}) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admins/users/$id');
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (role != null) body['role'] = role;
      if (phone != null) body['phone'] = phone;
      if (password != null && password.trim().isNotEmpty)
        body['password'] = password.trim();

      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(body));
      if (res.statusCode == 200) return (true, 'User updated successfully.');
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
      if (res.statusCode == 200) return (true, 'User deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Properties (Admin & Public) =================
  static Future<(bool, dynamic)> getAllProperties() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/properties');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body));
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addProperty(
      Map<String, dynamic> propertyData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/properties');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(propertyData));
      if (res.statusCode == 201)
        return (true, 'Property created successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateProperty(
      {required String id, required Map<String, dynamic> propertyData}) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/properties/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(propertyData));
      if (res.statusCode == 200)
        return (true, 'Property updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteProperty(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/properties/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200)
        return (true, 'Property deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Contracts =================
  static Future<(bool, dynamic)> getAllContracts() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/contracts');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Payments =================
  static Future<(bool, dynamic)> getAllPayments() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/payments');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Complaints =================
  static Future<(bool, dynamic)> getAllComplaints() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/complaints');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateComplaintStatus(
      String id, String status) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/complaints/$id/status');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode({'status': status}));
      if (res.statusCode == 200) return (true, 'Complaint status updated.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Reviews =================
  static Future<(bool, dynamic)> getAllReviews() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/reviews');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteReview(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/reviews/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, 'Review deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getReviewsByProperty(String propertyId) async {
    try {
      final url =
          Uri.parse('${AppConstants.baseUrl}/reviews/property/$propertyId');
      final res = await http.get(url);

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body));
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Failed to connect to the server.');
    }
  }

  static Future<(bool, String)> addReview({
    required String propertyId,
    required int rating,
    required String comment,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return (false, 'You must be logged in to post a review.');
      }

      final url = Uri.parse('${AppConstants.baseUrl}/reviews');
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'propertyId': propertyId,
          'rating': rating,
          'comment': comment,
        }),
      );

      if (res.statusCode == 201) {
        return (true, 'Review submitted successfully!');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Failed to connect to the server.');
    }
  }

  // ================= System Settings (Admin) =================
  static Future<(bool, List<SystemSetting>)> getSystemSettings() async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admin/settings');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return (true, data.map((e) => SystemSetting.fromJson(e)).toList());
      }
      return (false, <SystemSetting>[]);
    } catch (e) {
      return (false, <SystemSetting>[]);
    }
  }

  static Future<(bool, String)> updateSystemSetting(
      String key, dynamic value) async {
    try {
      final token = await getToken();
      final url = Uri.parse('${AppConstants.baseUrl}/admin/settings/$key');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode({'value': value}));
      if (res.statusCode == 200) return (true, 'Setting updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ==========================================================
  // REAL IMAGE UPLOAD FUNCTION
  // ==========================================================
  static Future<(bool, String?)> uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse('${AppConstants.baseUrl}/upload');
      final token = await getToken();
      final request = http.MultipartRequest('POST', url);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      final fileBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        fileBytes,
        filename: imageFile.name,
      );
      request.files.add(multipartFile);
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final dynamic imageUrl = responseData['url'];
        if (imageUrl is String) {
          print('Image uploaded successfully: $imageUrl');
          return (true, imageUrl);
        } else {
          return (false, 'Image URL format from server is invalid.');
        }
      } else {
        print('Image upload failed with status: ${response.statusCode}');
        return (false, _extractMessage(response.body));
      }
    } catch (e) {
      print('An error occurred during image upload: $e');
      return (false, 'An error occurred during image upload: ${e.toString()}');
    }
  }

  // ================= Helpers =================
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('userName');
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
      return map['message']?.toString() ??
          map['error']?.toString() ??
          'An unknown error occurred.';
    } catch (_) {
      if (body.isNotEmpty && body.length < 500) return body;
      return 'Request failed with an unreadable response.';
    }
  }
}
