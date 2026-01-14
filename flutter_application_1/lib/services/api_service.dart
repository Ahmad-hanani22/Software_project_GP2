import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';

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
  static String get baseUrl => AppConstants.baseUrl;

  // ================= Auth =================

  static Future<(bool, String)> register(
      {required String name,
      required String email,
      required String password}) async {
    final url = Uri.parse('$baseUrl/auth/register');
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
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final res = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Connection timeout. Please check your internet connection.');
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];

        if (token == null) {
          return (false, 'Login failed: Token not received from server.', null);
        }

        final userData = data['user'] as Map<String, dynamic>?;

        if (userData == null) {
          return (false, 'User data is missing in the server response.', null);
        }

        final String? role = userData['role']?.toString();
        final String? userName = userData['name']?.toString();
        final String? userId = userData['id']?.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        if (role != null) await prefs.setString('role', role);
        if (userName != null) await prefs.setString('userName', userName);
        if (userId != null) await prefs.setString('userId', userId);

        return (true, 'Logged in successfully.', role);
      } else {
        // Handle different error status codes
        String errorMessage = _extractMessage(res.body);

        if (res.statusCode == 400) {
          // User not found or invalid credentials
          if (errorMessage.toLowerCase().contains('not found')) {
            errorMessage =
                'User not found. Please check your email or register.';
          } else if (errorMessage.toLowerCase().contains('invalid') ||
              errorMessage.toLowerCase().contains('credentials')) {
            errorMessage = 'Invalid email or password. Please try again.';
          }
        } else if (res.statusCode == 403) {
          // Account not verified
          errorMessage =
              'Your account is not verified. Please check your email for verification link.';
        } else if (res.statusCode == 500) {
          errorMessage = 'Server error. Please try again later.';
        }

        return (false, errorMessage, null);
      }
    } on http.ClientException {
      return (
        false,
        'Could not connect to the server. Please check your internet connection.',
        null
      );
    } on FormatException {
      return (false, 'Invalid server response. Please try again.', null);
    } catch (e) {
      return (false, 'Login failed: ${e.toString()}', null);
    }
  }

  static Future<(bool, dynamic)> getMe() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/users/me');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body)['user']);
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // تحديث صورة البروفايل
  static Future<(bool, String)> updateUserProfileImage(String imageUrl) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/users/profile');

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'profilePicture': imageUrl}),
      );

      if (res.statusCode == 200) {
        return (true, 'Profile picture updated!');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Error: ${e.toString()}');
    }
  }

  // Delete profile picture
  static Future<(bool, String)> deleteUserProfileImage() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/users/profile');

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'profilePicture': ''}),
      );

      if (res.statusCode == 200) {
        return (true, 'Profile picture deleted!');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Error: ${e.toString()}');
    }
  }

  // ================= Dashboard =================
  static Future<(bool, dynamic)> getAdminDashboard() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/admin/dashboard');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getLandlordDashboard() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/landlord/dashboard');
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
      final url = Uri.parse('$baseUrl/admins/users');
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
      final url = Uri.parse('$baseUrl/admins/users');
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
      final url = Uri.parse('$baseUrl/admins/users/$id');
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
      final url = Uri.parse('$baseUrl/admins/users/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, 'User deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Properties =================
  static Future<(bool, dynamic)> getAllProperties() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/properties');

      // Build headers - properties endpoint is public, so token is optional
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception(
              'Connection timeout. Please check your internet connection.');
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Handle both array and object responses
        if (data is List) {
          return (true, data);
        } else if (data is Map && data.containsKey('properties')) {
          return (true, data['properties']);
        } else {
          return (true, []);
        }
      }
      return (false, _extractMessage(res.body));
    } on http.ClientException {
      return (
        false,
        'Could not connect to the server. Please check your internet connection.'
      );
    } on FormatException {
      return (false, 'Invalid server response. Please try again.');
    } catch (e) {
      return (false, 'Error fetching properties: ${e.toString()}');
    }
  }

  static Future<(bool, dynamic)> getPropertiesByOwner(String ownerId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/properties/owner/$ownerId');
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
      final url = Uri.parse('$baseUrl/properties');
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
      final url = Uri.parse('$baseUrl/properties/$id');
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
      final url = Uri.parse('$baseUrl/properties/$id');
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
      final url = Uri.parse('$baseUrl/contracts');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getContractById(String contractId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body));
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ✅ إحصائيات العقد
  static Future<(bool, dynamic)> getContractStatistics(
      String contractId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId/statistics');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body));
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ✅ الدفعات المرتبطة بالعقد
  static Future<(bool, dynamic)> getPaymentsByContract(
      String contractId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/payments/contract/$contractId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getUserContracts(String userId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/user/$userId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addContract({
    required String propertyId,
    required String tenantId,
    required String landlordId,
    required DateTime startDate,
    required DateTime endDate,
    required double rentAmount,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return (false, 'Authentication token not found.');

      final url = Uri.parse('$baseUrl/contracts');
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'propertyId': propertyId,
          'tenantId': tenantId,
          'landlordId': landlordId,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'rentAmount': rentAmount,
          'status': 'active',
        }),
      );

      if (res.statusCode == 201)
        return (true, 'Contract created successfully!');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Could not connect to the server: ${e.toString()}');
    }
  }

  static Future<(bool, String, dynamic)> requestContract({
    required String propertyId,
    required String landlordId,
    required double price,
    String? unitId, // إضافة دعم unitId
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/request');

      final bodyData = {
        'propertyId': propertyId,
        'landlordId': landlordId,
        'rentAmount': price,
      };

      // إضافة unitId إذا كان موجود
      if (unitId != null && unitId.isNotEmpty) {
        bodyData['unitId'] = unitId;
      }

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(bodyData),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final message = data is Map<String, dynamic> && data['message'] != null
            ? data['message'].toString()
            : 'Request sent! Contract is pending approval.';
        final contract = data is Map<String, dynamic> ? data['contract'] : null;
        return (true, message, contract);
      }
      return (false, _extractMessage(res.body), null);
    } catch (e) {
      return (false, e.toString(), null);
    }
  }

  static Future<(bool, String)> updateContract(
      String contractId, Map<String, dynamic> dataToUpdate) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(dataToUpdate),
      );
      if (res.statusCode == 200)
        return (true, 'Contract updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateContractStatus(
      String contractId, String status) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId');

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'status': status}),
      );

      if (res.statusCode == 200) {
        return (true, 'Contract status updated successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteContract(String contractId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200)
        return (true, 'Contract deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// ✍️ توقيع عقد إلكترونيًا
  static Future<(bool, String)> signContract(String contractId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId/sign');

      final res = await http.post(
        url,
        headers: _authHeaders(token),
      );

      if (res.statusCode == 200) {
        return (true, 'Contract signed successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 🔁 تجديد عقد
  static Future<(bool, String)> renewContract(
    String contractId, {
    DateTime? newStartDate,
    DateTime? newEndDate,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId/renew');

      final body = <String, dynamic>{};
      if (newStartDate != null) {
        body['newStartDate'] = newStartDate.toIso8601String();
      }
      if (newEndDate != null) {
        body['newEndDate'] = newEndDate.toIso8601String();
      }

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return (true, 'Contract renewed successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 🧨 طلب إنهاء عقد (يستخدم المسار الجديد في الباك إند)
  static Future<(bool, String)> requestContractTermination(
    String contractId, {
    String? reason,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/$contractId/terminate');

      final body = <String, dynamic>{};
      if (reason != null && reason.trim().isNotEmpty) {
        body['reason'] = reason.trim();
      }

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return (true, 'Termination request sent successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Payments =================
  static Future<(bool, dynamic)> getAllPayments() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/payments');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getUserPayments(String userId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/payments/user/$userId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 💳 إنشاء دفعة جديدة مرتبطة بعقد
  static Future<(bool, String)> addPayment({
    required String contractId,
    required double amount,
    required String method,
    String? receiptUrl,
  }) async {
    try {
      final token = await getToken();
      if (token == null) return (false, 'Authentication token not found.');

      final url = Uri.parse('$baseUrl/payments');
      final body = <String, dynamic>{
        'contractId': contractId,
        'amount': amount,
        'method': method,
        if (receiptUrl != null && receiptUrl.isNotEmpty)
          'receiptUrl': receiptUrl,
      };

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final message = data is Map<String, dynamic> && data['message'] != null
            ? data['message'].toString()
            : 'Payment created successfully.';
        return (true, message);
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Could not connect to the server: ${e.toString()}');
    }
  }

  static Future<(bool, String)> updatePayment(
      String paymentId, String? newStatus,
      {Map<String, dynamic>? additionalData}) async {
    try {
      final token = await getToken();
      if (token == null) return (false, 'Authentication token not found.');

      final url = Uri.parse('$baseUrl/payments/$paymentId');
      final body = <String, dynamic>{};
      if (newStatus != null) {
        body['status'] = newStatus;
      }
      if (additionalData != null) {
        body.addAll(additionalData);
      }

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return (true, 'Payment updated successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Could not connect to the server: ${e.toString()}');
    }
  }

  // ✅ NEW: Delete Payment
  static Future<(bool, String)> deletePayment(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/payments/$id');
      final res = await http.delete(url, headers: _authHeaders(token));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return (true, 'Payment deleted successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Maintenance =================
  static Future<(bool, dynamic)> getAllMaintenance() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getMaintenanceByProperty(
      String propertyId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance/property/$propertyId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getTenantRequests(String tenantId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance/tenant/$tenantId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> createMaintenance({
    required String propertyId,
    required String description,
    List<String>? images,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance');

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'propertyId': propertyId,
          'description': description,
          'images': images ?? [],
        }),
      );

      if (res.statusCode == 201) {
        return (true, 'Maintenance request submitted successfully!');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  static Future<(bool, String)> updateMaintenance(
      String id, String newStatus) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance/$id');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'status': newStatus}),
      );
      if (res.statusCode == 200) return (true, 'Maintenance status updated.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> assignTechnician(
      String maintenanceId, String technicianName) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance/$maintenanceId/assign');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'technicianName': technicianName}),
      );
      if (res.statusCode == 200)
        return (true, 'Technician assigned successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ✅ NEW: Delete Maintenance
  static Future<(bool, String)> deleteMaintenance(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/maintenance/$id');
      final res = await http.delete(url, headers: _authHeaders(token));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return (true, 'Maintenance request deleted successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // --- 🔒 Password Reset Logic ---

  static Future<(bool, String)> forgotPassword(String email) async {
    try {
      final url = Uri.parse('$baseUrl/password/forgot-password');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return (true, data['message']?.toString() ?? 'Code sent successfully');
      }

      return (false, data['message']?.toString() ?? 'Error sending code');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  static Future<(bool, String)> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/password/reset-password');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return (
          true,
          data['message']?.toString() ?? 'Password changed successfully'
        );
      }

      return (false, data['message']?.toString() ?? 'Error resetting password');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ================= CHAT (FIXED) =================

  // 1. ✅ جلب قائمة المستخدمين (تم الإصلاح: إرجاع قائمة فارغة عند الفشل بدلاً من String)
  static Future<(bool, List<dynamic>)> getChatUsers() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/users/chat-list');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // التحقق من الصيغ المحتملة وتحويلها إلى قائمة صراحةً
        if (data is Map<String, dynamic> && data['users'] != null) {
          return (true, (data['users'] as List).cast<dynamic>());
        } else if (data is List) {
          return (true, data.cast<dynamic>());
        }
      }
      // إرجاع قائمة فارغة في حال الفشل
      return (false, <dynamic>[]);
    } catch (e) {
      print("Chat Error: $e");
      return (false, <dynamic>[]);
    }
  }

  // 2. إرسال رسالة (مع دعم المرفقات)
  static Future<(bool, dynamic)> sendMessage({
    required String receiverId,
    required String message,
    List<String>? attachments,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/chats');
      final body = {
        'receiverId': receiverId,
        'message': message,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
      };
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );
      if (res.statusCode == 201) return (true, 'Message sent');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // Upload audio file
  static Future<(bool, String?)> uploadAudio(File audioFile) async {
    try {
      final url = Uri.parse('$baseUrl/upload');
      final token = await getToken();
      final request = http.MultipartRequest('POST', url);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final fileBytes = await audioFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image', // Backend accepts 'image' field for any file
        fileBytes,
        filename: audioFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final dynamic fileUrl = responseData['url'];
        if (fileUrl is String) {
          return (true, fileUrl);
        }
        return (false, 'Invalid URL format from server');
      }
      return (false, _extractMessage(response.body));
    } catch (e) {
      return (false, 'Error uploading audio: ${e.toString()}');
    }
  }

  // 3. ✅ جلب المحادثة (تم الإصلاح)
  static Future<(bool, List<dynamic>)> getConversation(
      String otherUserId) async {
    try {
      final token = await getToken();
      final myId = (await SharedPreferences.getInstance()).getString('userId');
      if (myId == null) return (false, <dynamic>[]);

      final url = Uri.parse('$baseUrl/chats/$myId/$otherUserId');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return (true, data.cast<dynamic>());
        // لو كانت البيانات بصيغة أخرى، نرجع قائمة فارغة
        return (false, <dynamic>[]);
      }
      return (false, <dynamic>[]);
    } catch (e) {
      return (false, <dynamic>[]);
    }
  }

  // 4. جلب قائمة المحادثات السابقة
  static Future<(bool, dynamic)> getUserChats() async {
    try {
      final token = await getToken();
      final myId = (await SharedPreferences.getInstance()).getString('userId');
      if (myId == null) return (false, "User ID not found");

      final url = Uri.parse('$baseUrl/chats/user/$myId');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // 5. جلب قائمة الأدمنز للدردشة
  static Future<(bool, List<dynamic>)> getAdminUsers() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/users/admins');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return (true, data.cast<dynamic>());
        return (true, []);
      }
      return (false, <dynamic>[]);
    } catch (e) {
      return (false, <dynamic>[]);
    }
  }

  // ================= Complaints =================
  static Future<(bool, dynamic)> getAllComplaints() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/complaints');
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
      final url = Uri.parse('$baseUrl/complaints/$id/status');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'status': status}),
      );
      if (res.statusCode == 200) return (true, 'Complaint status updated.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // تقديم شكوى من المستأجر
  static Future<(bool, String)> createComplaint({
    required String description,
    required String category, // financial / maintenance / behavior
    String? againstUserId,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/complaints');

      final body = {
        'description': description,
        'category': category,
        if (againstUserId != null) 'againstUserId': againstUserId,
        if (attachments != null) 'attachments': attachments,
      };

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (res.statusCode == 201) {
        return (true, 'Complaint submitted successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // رفع مرفق شكوى واحد (صورة / ملف) – يعيد رابط Cloudinary + الاسم
  static Future<(bool, Map<String, String>?)> uploadComplaintAttachment(
      XFile file) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/complaints/upload-attachment');

      final request = http.MultipartRequest('POST', url);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final bytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (
          true,
          {
            'url': data['url']?.toString() ?? '',
            'name': data['name']?.toString() ?? file.name,
          }
        );
      }

      return (false, null);
    } catch (e) {
      return (false, null);
    }
  }

  // ✅ NEW: Delete Complaint
  static Future<(bool, String)> deleteComplaint(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/complaints/$id');
      final res = await http.delete(url, headers: _authHeaders(token));

      if (res.statusCode == 200 || res.statusCode == 204) {
        return (true, 'Complaint deleted successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Reviews =================
  static Future<(bool, dynamic)> getAllReviews() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/reviews');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateReview(
      String reviewId, Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/reviews/$reviewId');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(data),
      );
      if (res.statusCode == 200) return (true, 'Review updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteReview(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/reviews/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, 'Review deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getReviewsByProperty(String propertyId) async {
    try {
      final url = Uri.parse('$baseUrl/reviews/property/$propertyId');
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

      final url = Uri.parse('$baseUrl/reviews');
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

  static Future<(bool, String)> sendRequestToOwner({
    required String ownerId,
    required String propertyTitle,
    required String actionType,
    required String requesterName,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/notifications/direct');
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'recipientId': ownerId,
          'title': "New $actionType Request",
          'message':
              "User $requesterName wants to $actionType your property: $propertyTitle",
          'type': 'system'
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return (true, "Request sent to owner successfully");
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Notifications (Admin) =================
  static Future<(bool, dynamic)> getAllNotifications() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/notifications');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> createNotification({
    required String recipients,
    required String message,
    String? title,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/notifications');
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'recipients': recipients,
          'message': message,
          if (title != null) 'title': title,
        }),
      );
      if (res.statusCode == 200) return (true, _extractMessage(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= System Settings (Admin) =================
  static Future<(bool, List<SystemSetting>)> getSystemSettings() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/admin/settings');
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
      final url = Uri.parse('$baseUrl/admin/settings/$key');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode({'value': value}));
      if (res.statusCode == 200) return (true, 'Setting updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Real Image Upload =================
  static Future<(bool, String?)> uploadImage(XFile imageFile) async {
    try {
      final url = Uri.parse('$baseUrl/upload');
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
    await prefs.remove('userId');
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

  // ✅ دالة جديدة: تحديد الرسائل كمقروءة
  static Future<bool> markMessagesAsRead(String senderId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/chats/read');

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'senderId': senderId}),
      );

      return res.statusCode == 200;
    } catch (e) {
      print("Error marking messages as read: $e");
      return false;
    }
  }

  // ================= FCM Token Registration =================
  /// تسجيل FCM Token للباك إند
  static Future<(bool, String)> registerFCMToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/users/$userId/fcm-token');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'fcmToken': fcmToken}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return (true, 'FCM Token registered successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Error registering FCM token: ${e.toString()}');
    }
  }

  // جلب إشعارات المستخدم
  static Future<(bool, List<dynamic>)> getUserNotifications() async {
    try {
      final token = await getToken();
      final userId =
          (await SharedPreferences.getInstance()).getString('userId');
      if (userId == null) return (false, []);

      final url = Uri.parse('$baseUrl/notifications/user/$userId');
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body) as List<dynamic>);
      }
      return (false, []);
    } catch (e) {
      return (false, []);
    }
  }

  // وضع الإشعار كمقروء
  static Future<void> markNotificationRead(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/notifications/$id/read');
      await http.put(url, headers: _authHeaders(token));
    } catch (_) {}
  }

  // ================= Units =================
  static Future<(bool, dynamic)> getAllUnits(
      {String? propertyId, String? status}) async {
    try {
      final token = await getToken();
      String urlString = '$baseUrl/units';
      final queryParams = <String>[];
      if (propertyId != null) queryParams.add('propertyId=$propertyId');
      if (status != null) queryParams.add('status=$status');
      if (queryParams.isNotEmpty) urlString += '?${queryParams.join('&')}';

      final url = Uri.parse(urlString);
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getUnitById(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/units/$id');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getUnitsByProperty(String propertyId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/units/property/$propertyId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addUnit(Map<String, dynamic> unitData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/units');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(unitData));
      if (res.statusCode == 201) return (true, 'Unit created successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateUnit(
      String id, Map<String, dynamic> unitData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/units/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(unitData));
      if (res.statusCode == 200) return (true, 'Unit updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteUnit(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/units/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, 'Unit deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getUnitStats(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/units/$id/stats');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Expenses =================
  static Future<(bool, dynamic)> getAllExpenses({
    String? propertyId,
    String? unitId,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await getToken();
      String urlString = '$baseUrl/expenses';
      final queryParams = <String>[];
      if (propertyId != null) queryParams.add('propertyId=$propertyId');
      if (unitId != null) queryParams.add('unitId=$unitId');
      if (type != null) queryParams.add('type=$type');
      if (startDate != null) queryParams.add('startDate=$startDate');
      if (endDate != null) queryParams.add('endDate=$endDate');
      if (queryParams.isNotEmpty) urlString += '?${queryParams.join('&')}';

      final url = Uri.parse(urlString);
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addExpense(
      Map<String, dynamic> expenseData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/expenses');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(expenseData));
      if (res.statusCode == 201) return (true, 'Expense added successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateExpense(
      String id, Map<String, dynamic> expenseData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/expenses/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(expenseData));
      if (res.statusCode == 200) return (true, 'Expense updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteExpense(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/expenses/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, 'Expense deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getExpenseStats({
    String? propertyId,
    String? unitId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await getToken();
      String urlString = '$baseUrl/expenses/stats';
      final queryParams = <String>[];
      if (propertyId != null) queryParams.add('propertyId=$propertyId');
      if (unitId != null) queryParams.add('unitId=$unitId');
      if (startDate != null) queryParams.add('startDate=$startDate');
      if (endDate != null) queryParams.add('endDate=$endDate');
      if (queryParams.isNotEmpty) urlString += '?${queryParams.join('&')}';

      final url = Uri.parse(urlString);
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Deposits =================
  static Future<(bool, dynamic)> getAllDeposits() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/deposits');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getDepositByContract(String contractId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/deposits/contract/$contractId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addDeposit(
      Map<String, dynamic> depositData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/deposits');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(depositData));
      if (res.statusCode == 201) return (true, 'Deposit added successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateDeposit(
      String id, Map<String, dynamic> depositData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/deposits/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(depositData));
      if (res.statusCode == 200) return (true, 'Deposit updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Invoices =================
  static Future<(bool, dynamic)> getAllInvoices({String? contractId}) async {
    try {
      final token = await getToken();
      String urlString = '$baseUrl/invoices';
      if (contractId != null) urlString += '?contractId=$contractId';
      final url = Uri.parse(urlString);
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getInvoiceById(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/invoices/$id');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> createInvoice(
      Map<String, dynamic> invoiceData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/invoices');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(invoiceData));
      if (res.statusCode == 201) return (true, 'Invoice created successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateInvoice(
      String id, Map<String, dynamic> invoiceData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/invoices/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(invoiceData));
      if (res.statusCode == 200) return (true, 'Invoice updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Occupancy History =================
  static Future<(bool, dynamic)> getOccupancyByUnit(String unitId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/occupancy-history/unit/$unitId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getOccupancyByTenant(String tenantId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/occupancy-history/tenant/$tenantId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addOccupancyHistory(
      Map<String, dynamic> occupancyData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/occupancy-history');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(occupancyData));
      if (res.statusCode == 201)
        return (true, 'Occupancy history added successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Property History =================
  static Future<(bool, dynamic)> getPropertyHistory(String propertyId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/property-history/property/$propertyId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addPropertyHistory(
      Map<String, dynamic> historyData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/property-history');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(historyData));
      if (res.statusCode == 201)
        return (true, 'Property history added successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Ownership =================
  static Future<(bool, dynamic)> getPropertyOwnership(String propertyId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/ownership/property/$propertyId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getOwnerProperties(String ownerId) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/ownership/owner/$ownerId');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addOwnership(
      Map<String, dynamic> ownershipData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/ownership');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(ownershipData));
      if (res.statusCode == 201) return (true, 'Ownership added successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateOwnership(
      String id, Map<String, dynamic> ownershipData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/ownership/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(ownershipData));
      if (res.statusCode == 200)
        return (true, 'Ownership updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteOwnership(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/ownership/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200)
        return (true, 'Ownership deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Buildings =================
  static Future<(bool, dynamic)> getAllBuildings() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/buildings');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, dynamic)> getBuildingById(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/buildings/$id');
      final res = await http.get(url, headers: _authHeaders(token));
      if (res.statusCode == 200) return (true, jsonDecode(res.body));
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> addBuilding(
      Map<String, dynamic> buildingData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/buildings');
      final res = await http.post(url,
          headers: _authHeaders(token), body: jsonEncode(buildingData));
      if (res.statusCode == 201)
        return (true, 'Building created successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updateBuilding(
      String id, Map<String, dynamic> buildingData) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/buildings/$id');
      final res = await http.put(url,
          headers: _authHeaders(token), body: jsonEncode(buildingData));
      if (res.statusCode == 200)
        return (true, 'Building updated successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deleteBuilding(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/buildings/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200)
        return (true, 'Building deleted successfully.');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ================= Property Types Management =================

  static Future<(bool, dynamic)> getPropertyTypes(
      {bool activeOnly = false}) async {
    try {
      final url = Uri.parse(
          '$baseUrl/property-types${activeOnly ? '?activeOnly=true' : ''}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          return (true, data['data']);
        }
        return (true, []);
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> createPropertyType({
    required String name,
    required String displayName,
    required String icon,
    String? description,
    int order = 0,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/property-types');
      final body = jsonEncode({
        'name': name,
        'displayName': displayName,
        'icon': icon,
        'description': description,
        'order': order,
      });
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: body,
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final message = data['message']?.toString() ??
            'Property type created successfully.';
        return (true, message);
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> updatePropertyType({
    required String id,
    String? name,
    String? displayName,
    String? icon,
    String? description,
    int? order,
    bool? isActive,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/property-types/$id');
      final bodyData = <String, dynamic>{};
      if (name != null) bodyData['name'] = name;
      if (displayName != null) bodyData['displayName'] = displayName;
      if (icon != null) bodyData['icon'] = icon;
      if (description != null) bodyData['description'] = description;
      if (order != null) bodyData['order'] = order;
      if (isActive != null) bodyData['isActive'] = isActive;

      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode(bodyData),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final message = data['message']?.toString() ??
            'Property type updated successfully.';
        return (true, message);
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> deletePropertyType(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/property-types/$id');
      final res = await http.delete(url, headers: _authHeaders(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final message = data['message']?.toString() ??
            'Property type deleted successfully.';
        return (true, message);
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }

  static Future<(bool, String)> togglePropertyTypeStatus(String id) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/property-types/$id/toggle');
      final res = await http.patch(url, headers: _authHeaders(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final message = data['message']?.toString() ??
            'Property type status updated successfully.';
        return (true, message);
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
    }
  }
}
