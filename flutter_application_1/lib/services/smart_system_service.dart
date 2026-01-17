import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class SmartSystemService {
  static String get baseUrl => AppConstants.baseUrl;

  // Helper method to get auth token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Helper method to get user ID
  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Helper method for auth headers
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ========================================================
  // 🧠 1️⃣ جمع البيانات (Data Collection)
  // ========================================================

  /// تسجيل زيارة عقار
  static Future<(bool, String)> trackPropertyView({
    required String propertyId,
    int? viewDuration, // بالثواني
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, 'Please login first');
      }

      final url = Uri.parse('$baseUrl/smart-system/track-view');
      final headers = await _getAuthHeaders();

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              'propertyId': propertyId,
              'viewDuration': viewDuration ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return (true, 'View tracked successfully');
      }
      return (false, 'Failed to track view');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  /// إضافة/إزالة من المفضلة
  static Future<(bool, String, bool)> toggleFavorite({
    required String propertyId,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, 'Please login first', false);
      }

      final url = Uri.parse('$baseUrl/smart-system/toggle-favorite');
      final headers = await _getAuthHeaders();

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              'propertyId': propertyId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isFavorite = (data['isFavorite'] as bool?) ?? false;
        final message = (data['message'] ?? 'Updated successfully').toString();
        return (true, message, isFavorite);
      }
      return (false, 'Failed to update', false);
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}', false);
    }
  }

  /// تسجيل عملية بحث
  static Future<(bool, String)> trackSearch({
    String? query,
    Map<String, dynamic>? filters,
    int? resultsCount,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, 'Please login first');
      }

      final url = Uri.parse('$baseUrl/smart-system/track-search');
      final headers = await _getAuthHeaders();

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              'query': query ?? '',
              'filters': filters ?? {},
              'resultsCount': resultsCount ?? 0,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return (true, 'Search tracked successfully');
      }
      return (false, 'Failed to track search');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 2️⃣ تحليل السلوك (User Behavior Analysis)
  // ========================================================

  /// تحليل نمط المستخدم
  static Future<(bool, dynamic)> analyzeUserBehavior() async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, 'Please login first');
      }

      final url = Uri.parse('$baseUrl/smart-system/analyze-behavior/$userId');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['analysis']);
      }
      return (false, 'Failed to analyze behavior');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 3️⃣ نظام الاقتراحات (Recommendation Engine)
  // ========================================================

  /// الحصول على اقتراحات ذكية
  static Future<(bool, List<dynamic>, dynamic)> getSmartRecommendations({
    int limit = 10,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, <dynamic>[], 'Please login first');
      }

      final url = Uri.parse(
        '$baseUrl/smart-system/recommendations/$userId?limit=$limit',
      );
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recommendations = (data['recommendations'] as List?) ?? [];
        final userProfile = data['userProfile'];
        final behaviorAnalysis = data['behaviorAnalysis'];

        return (
          true,
          recommendations,
          {
            'userProfile': userProfile,
            'behaviorAnalysis': behaviorAnalysis,
          }
        );
      }
      // If status code is not 200, return error message
      final errorData = jsonDecode(response.body);
      final errorMessage =
          errorData['message'] ?? 'Failed to load recommendations';
      return (false, <dynamic>[], errorMessage);
    } catch (e) {
      return (false, <dynamic>[], 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 4️⃣ الترتيب الذكي (Smart Ranking)
  // ========================================================

  /// ترتيب العقارات حسب التوافق
  static Future<(bool, List<dynamic>)> getSmartRankedProperties({
    Map<String, dynamic>? filters,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, []);
      }

      final url = Uri.parse('$baseUrl/smart-system/rank-properties/$userId');
      final headers = await _getAuthHeaders();

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'filters': filters ?? {},
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final properties = (data['properties'] as List?) ?? [];
        return (true, properties);
      }
      return (false, <dynamic>[]);
    } catch (e) {
      return (false, []);
    }
  }

  // ========================================================
  // 🧠 5️⃣ التوصيف الذكي (User Profiling)
  // ========================================================

  /// تحديث User Profile
  static Future<(bool, dynamic)> updateUserProfile() async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, 'Please login first');
      }

      final url = Uri.parse('$baseUrl/smart-system/update-profile/$userId');
      final headers = await _getAuthHeaders();

      final response = await http.put(url, headers: headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['profile']);
      }
      return (false, 'Failed to update profile');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 5️⃣5️⃣ Update User Preferences (Filter Settings)
  // ========================================================

  /// Update user preferences and filters
  static Future<(bool, String)> updateUserPreferences({
    Map<String, dynamic>? filters,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, 'Please login first');
      }

      final url = Uri.parse('$baseUrl/smart-system/preferences/$userId');
      final headers = await _getAuthHeaders();

      final response = await http
          .put(
            url,
            headers: headers,
            body: jsonEncode({
              'filters': filters ?? {},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return (true, 'Preferences saved successfully');
      }
      return (false, 'Failed to save preferences');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 6️⃣ الذكاء المالي (Financial Intelligence)
  // ========================================================

  /// تحليل السعر مقابل السوق
  static Future<(bool, dynamic)> analyzePropertyPrice({
    required String propertyId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/smart-system/analyze-price/$propertyId');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['analysis']);
      }
      return (false, 'Failed to analyze price');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 7️⃣ ذكاء الموثوقية (Trust Intelligence)
  // ========================================================

  /// حساب Trust Score للعقار
  static Future<(bool, dynamic)> calculateTrustScore({
    required String propertyId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/smart-system/trust-score/$propertyId');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['trustScore']);
      }
      return (false, 'Failed to calculate Trust Score');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 8️⃣ ذكاء الصيانة والجودة
  // ========================================================

  /// تحليل الصيانة
  static Future<(bool, dynamic)> analyzeMaintenance({
    required String propertyId,
  }) async {
    try {
      final url =
          Uri.parse('$baseUrl/smart-system/analyze-maintenance/$propertyId');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['analysis']);
      }
      return (false, 'Failed to analyze maintenance');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 9️⃣ الذكاء الزمني (Time-Based Intelligence)
  // ========================================================

  /// تحليل الطلب الموسمي
  static Future<(bool, dynamic)> analyzeSeasonalDemand({
    required String propertyId,
  }) async {
    try {
      final url =
          Uri.parse('$baseUrl/smart-system/seasonal-demand/$propertyId');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['analysis']);
      }
      return (false, 'Failed to analyze seasonal demand');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🔔 10️⃣ نظام التنبيهات الذكية
  // ========================================================

  /// الحصول على التنبيهات الذكية
  static Future<(bool, List<dynamic>)> getSmartNotifications() async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return (false, []);
      }

      final url = Uri.parse('$baseUrl/smart-system/notifications/$userId');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = (data['notifications'] as List?) ?? [];
        return (true, notifications);
      }
      return (false, <dynamic>[]);
    } catch (e) {
      return (false, []);
    }
  }

  // ========================================================
  // 🧠 1️⃣1️⃣ ذكاء المالك (Owner Intelligence)
  // ========================================================

  /// تحليل أداء عقار للمالك
  static Future<(bool, dynamic)> getOwnerPropertyInsights({
    required String propertyId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/smart-system/owner-insights/$propertyId');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['insights']);
      }
      return (false, 'Failed to get insights');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }

  // ========================================================
  // 🧠 1️⃣2️⃣ ذكاء الإدارة (Admin Intelligence)
  // ========================================================

  /// إحصائيات النظام للأدمن
  static Future<(bool, dynamic)> getAdminIntelligence() async {
    try {
      final url = Uri.parse('$baseUrl/smart-system/admin-intelligence');
      final headers = await _getAuthHeaders();

      final response = await http.get(url, headers: headers).timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (true, data['intelligence']);
      }
      return (false, 'Failed to get statistics');
    } catch (e) {
      return (false, 'Connection error: ${e.toString()}');
    }
  }
}
