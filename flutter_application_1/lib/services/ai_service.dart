// services/ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class AIService {
  static String get baseUrl => AppConstants.baseUrl;

  /// الحصول على Token من SharedPreferences
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// إرسال سؤال للـ AI
  static Future<(bool, String, Map<String, dynamic>?)> askAI({
    required String question,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return (false, 'يجب تسجيل الدخول أولاً', null);
      }

      final url = Uri.parse('$baseUrl/ai/chat');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question': question,
        }),
      ).timeout(
        const Duration(seconds: 180), // 3 دقائق للموديلات الكبيرة
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال. الموديل قد يكون كبيراً - جرب موديل أصغر أو انتظر قليلاً.');
        },
      );

      // ✅ معالجة جميع حالات الأخطاء
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return (true, (data['response'] ?? 'لا توجد إجابة') as String, data);
        } else {
          // ✅ إضافة رسالة المساعدة إذا كانت موجودة
          final message = (data['message'] ?? 'حدث خطأ غير متوقع') as String;
          final help = data['help'] as String?;
          
          if (help != null && help.isNotEmpty) {
            return (false, '$message\n\n$help', null);
          }
          
          return (false, message, null);
        }
      } else if (response.statusCode == 429) {
        // ✅ معالجة Rate Limit أو Quota
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final code = errorData['code'] as String?;
        
        // إذا كان الخطأ بسبب Quota
        if (code == 'insufficient_quota') {
          return (
            false,
            'انتهى الرصيد المتاح في حساب OpenAI. يرجى إضافة رصيد أو التحقق من إعدادات الدفع.',
            null
          );
        }
        
        // إذا كان Rate Limit عادي
        final retryAfter = errorData['retryAfter'] ?? 60;
        return (
          false,
          'تم تجاوز الحد المسموح من الطلبات. يرجى المحاولة بعد $retryAfter ثانية.',
          null
        );
      } else if (response.statusCode == 402) {
        // ✅ معالجة خطأ Quota (Payment Required)
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return (
          false,
          errorData['message'] as String? ?? 'انتهى الرصيد المتاح في حساب OpenAI. يرجى إضافة رصيد.',
          null
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return (false, 'يرجى تسجيل الدخول مرة أخرى', null);
      } else if (response.statusCode == 402) {
        // ✅ معالجة خطأ Quota (Payment Required)
        return (false, 'انتهى الرصيد المتاح في حساب OpenAI. يرجى إضافة رصيد.', null);
      } else if (response.statusCode >= 500) {
        // ✅ معالجة أخطاء السيرفر
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'خدمة AI غير متاحة حاليًا';
        final help = errorData['help'] as String?;
        
        // إذا كان هناك رسالة مساعدة، أضفها
        if (help != null && help.isNotEmpty) {
          return (false, '$message\n\n$help', null);
        }
        
        return (false, message, null);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'حدث خطأ في الاتصال';
        final help = errorData['help'] as String?;
        
        // إذا كان هناك رسالة مساعدة، أضفها
        if (help != null && help.isNotEmpty) {
          return (false, '$message\n\n$help', null);
        }
        
        return (false, message, null);
      }
    } catch (e) {
      return (false, 'خطأ: ${e.toString()}', null);
    }
  }

  /// فحص حالة AI Service
  static Future<(bool, Map<String, dynamic>)> checkHealth() async {
    try {
      final url = Uri.parse('$baseUrl/ai/health');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (true, data);
      } else {
        return (false, {'message': 'AI Service غير متاح'} as Map<String, dynamic>);
      }
    } catch (e) {
      return (false, {'message': 'خطأ: ${e.toString()}'});
    }
  }

  /// Chatbot with database integration (Smart System)
  /// Body: { question: string, filters?: { budget?, city?, rooms?, type?, operation? } }
  static Future<(bool, String, Map<String, dynamic>?)> askAIWithData({
    required String question,
    Map<String, dynamic>? filters,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return (false, 'يجب تسجيل الدخول أولاً', null);
      }

      final url = Uri.parse('$baseUrl/ai/recommend');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question': question,
          'filters': filters ?? {},
        }),
      ).timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return (true, (data['response'] ?? 'لا توجد إجابة') as String, data);
        } else {
          return (false, (data['message'] ?? 'حدث خطأ غير متوقع') as String, null);
        }
      } else if (response.statusCode >= 500) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'خدمة AI غير متاحة حاليًا';
        return (false, message, null);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final message = errorData['message'] as String? ?? 'حدث خطأ في الاتصال';
        return (false, message, null);
      }
    } catch (e) {
      return (false, 'خطأ: ${e.toString()}', null);
    }
  }
}
