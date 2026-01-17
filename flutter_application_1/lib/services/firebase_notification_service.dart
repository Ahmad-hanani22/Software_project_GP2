import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // ✅ للوصول إلى navigatorKey

/// 🔔 خدمة إشعارات Firebase مع دعم الصوت
class FirebaseNotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Stream controller للإشعارات
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageController.stream;

  bool _isInitialized = false;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. طلب صلاحيات الإشعارات
      await _requestPermissions();

      // 2. تهيئة Local Notifications (فقط على Android و iOS، ليس على الويب)
      if (!kIsWeb) {
        await _initializeLocalNotifications();
      } else {
        debugPrint(
            '🌐 Web platform: Skipping local notifications initialization');
      }

      // 3. إعداد معالجات الإشعارات
      _setupMessageHandlers();

      // 4. الحصول على FCM Token وإرساله للباك إند
      await _registerFCMToken();

      // 5. إعداد معالج الإشعارات في الخلفية (فقط على Android و iOS، ليس على الويب)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      } else {
        debugPrint(
            '🌐 Web platform: Background messages handled by service worker');
      }

      _isInitialized = true;
      debugPrint('✅ Firebase Notification Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Firebase Notification Service: $e');
    }
  }

  /// طلب صلاحيات الإشعارات
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true, // ✅ تفعيل الصوت
    );

    debugPrint(
        '📱 Notification permission status: ${settings.authorizationStatus}');
  }

  /// تهيئة Local Notifications (فقط على Android و iOS)
  Future<void> _initializeLocalNotifications() async {
    // على الويب، لا نحتاج إلى local notifications
    if (kIsWeb) return;

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // إنشاء قناة إشعارات Android مع الصوت
    await _createNotificationChannel();
  }

  /// إنشاء قناة إشعارات Android مع الصوت
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'shaqati_messages', // id
      'SHAQATI Messages', // name
      description: 'Notifications for new messages and updates',
      importance: Importance.high,
      playSound: true, // ✅ تفعيل الصوت
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('default'), // صوت افتراضي
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// إعداد معالجات الإشعارات
  void _setupMessageHandlers() {
    // معالج الإشعارات عند فتح التطبيق (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          '📨 Notification received in foreground: ${message.notification?.title}');

      // ✅ عرض SnackBar/Alert في Foreground على جميع المنصات
      _showForegroundNotification(message);

      // على Android/iOS، نعرض أيضاً local notification
      if (!kIsWeb) {
        _showLocalNotification(message);
        _playNotificationSound();
      }

      _messageController.add(message);
    });

    // معالج الإشعارات عند فتح التطبيق من الإشعار (Background/Terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification opened app: ${message.notification?.title}');
      _messageController.add(message);
    });

    // التحقق من وجود إشعار عند فتح التطبيق
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
            '📱 App opened from notification: ${message.notification?.title}');
        _messageController.add(message);
      }
    });
  }

  /// عرض إشعار محلي مع الصوت (فقط على Android و iOS)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // على الويب، لا نحتاج إلى local notifications
    if (kIsWeb) return;

    final RemoteNotification? notification = message.notification;

    if (notification == null) return;

    // إعدادات Android
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'shaqati_messages',
      'SHAQATI Messages',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true, // ✅ تشغيل الصوت
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    // إعدادات iOS
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true, // ✅ تفعيل الصوت على iOS
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'SHAQATI',
      notification.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  /// ✅ عرض إشعار في Foreground (SnackBar/Alert)
  void _showForegroundNotification(RemoteMessage message) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('⚠️ Navigator context not available for showing notification');
        return;
      }

      final title = message.notification?.title ?? 'SHAQATI';
      final body = message.notification?.body ?? 'New notification';
      final data = message.data;

      // عرض SnackBar مع إمكانية النقر للانتقال
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00695C), // Primary color
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              // ✅ يمكن إضافة navigation logic هنا بناءً على data
              debugPrint('📱 Notification tapped: ${data.toString()}');
              // مثال: إذا كان هناك entityType و entityId في data، يمكن الانتقال للصفحة المناسبة
              if (data.containsKey('entityType') && data.containsKey('entityId')) {
                final entityType = data['entityType'];
                final entityId = data['entityId'];
                // يمكن إضافة navigation logic هنا
                debugPrint('🔗 Navigate to: $entityType/$entityId');
              }
            },
          ),
        ),
      );

      debugPrint('✅ Foreground notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing foreground notification: $e');
    }
  }

  /// تشغيل صوت الإشعار
  Future<void> _playNotificationSound() async {
    try {
      // الصوت سيتم تشغيله تلقائياً من خلال نظام الإشعارات
      debugPrint('🔔 Notification sound will play automatically via system');
    } catch (e) {
      debugPrint('⚠️ Could not play notification sound: $e');
    }
  }

  /// معالج النقر على الإشعار
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // يمكنك إضافة navigation logic هنا
  }

  /// تسجيل FCM Token وإرساله للباك إند
  Future<void> _registerFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');

        // حفظ Token محلياً
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        // إرسال Token للباك إند
        await _sendTokenToBackend(token);

        // الاستماع لتحديثات Token
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 FCM Token refreshed: $newToken');
          prefs.setString('fcm_token', newToken);
          _sendTokenToBackend(newToken);
        });
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// إرسال FCM Token للباك إند
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final userId =
          (await SharedPreferences.getInstance()).getString('userId');
      if (userId == null) {
        debugPrint('⚠️ User ID not found, skipping token registration');
        return;
      }

      final (success, message) = await ApiService.registerFCMToken(
        userId: userId,
        fcmToken: token,
      );

      if (success) {
        debugPrint('✅ FCM Token sent to backend for user: $userId');
      } else {
        debugPrint('❌ Failed to register FCM token: $message');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM token to backend: $e');
    }
  }

  /// الحصول على FCM Token الحالي
  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// إعادة إرسال FCM Token للباك إند (مفيد بعد Login)
  Future<void> resendTokenToBackend() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('❌ Error resending FCM token: $e');
    }
  }

  /// إلغاء الاشتراك من جميع المواضيع
  Future<void> unsubscribeFromAll() async {
    await _firebaseMessaging.unsubscribeFromTopic('all');
  }

  /// الاشتراك في موضوع معين
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  /// تنظيف الموارد
  void dispose() {
    _messageController.close();
    _audioPlayer.dispose();
  }
}

/// معالج الإشعارات في الخلفية (يجب أن يكون top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
      '📨 Background notification received: ${message.notification?.title}');
  // يمكنك إضافة معالجة إضافية هنا
}
