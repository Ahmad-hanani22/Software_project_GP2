import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

// ✅ تعريف كلاس الإعدادات
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
  // ⚠️ ملاحظة: تأكد من الرابط (localhost للويب، 10.0.2.2 للمحاكي)
  static const String baseUrl = "http://localhost:3000/api";

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
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];

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
      }
      return (false, _extractMessage(res.body), null);
    } catch (e) {
      return (false, 'Could not connect to the server.', null);
    }
  }

  static Future<(bool, dynamic)> getMe() async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/auth/me');
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
      final res = await http.get(url, headers: _authHeaders(token));

      if (res.statusCode == 200) {
        return (true, jsonDecode(res.body));
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
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

  static Future<(bool, String)> requestContract({
    required String propertyId,
    required String landlordId,
    required double price,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/contracts/request');

      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'propertyId': propertyId,
          'landlordId': landlordId,
          'rentAmount': price,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        return (true, 'Request sent! Contract is pending approval.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
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

  static Future<(bool, String)> updatePayment(
      String paymentId, String newStatus) async {
    try {
      final token = await getToken();
      if (token == null) return (false, 'Authentication token not found.');

      final url = Uri.parse('$baseUrl/payments/$paymentId');
      final res = await http.put(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({'status': newStatus}),
      );

      if (res.statusCode == 200) {
        return (true, 'Payment status updated successfully.');
      }
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, 'Could not connect to the server: ${e.toString()}');
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

  // 2. إرسال رسالة
  static Future<(bool, dynamic)> sendMessage({
    required String receiverId,
    required String message,
  }) async {
    try {
      final token = await getToken();
      final url = Uri.parse('$baseUrl/chats');
      final res = await http.post(
        url,
        headers: _authHeaders(token),
        body: jsonEncode({
          'receiverId': receiverId,
          'message': message,
        }),
      );
      if (res.statusCode == 201) return (true, 'Message sent');
      return (false, _extractMessage(res.body));
    } catch (e) {
      return (false, e.toString());
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
}
