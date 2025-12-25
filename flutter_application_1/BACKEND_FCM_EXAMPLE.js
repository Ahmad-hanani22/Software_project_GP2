// ============================================
// 🔔 مثال على إعداد Firebase Cloud Messaging في الباك إند
// ============================================

// 1. تثبيت Firebase Admin SDK:
// npm install firebase-admin

// 2. تهيئة Firebase Admin في ملف منفصل (مثلاً: config/firebaseAdmin.js)
const admin = require('firebase-admin');
const serviceAccount = require('./config/serviceAccountKey.json'); // ملف Service Account Key

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin initialized');
}

// 3. تحديث User Model لإضافة fcmToken:
/*
const userSchema = new Schema({
  // ... باقي الحقول
  fcmToken: {
    type: String,
    default: null,
  },
});
*/

// 4. Route لتسجيل FCM Token:
/*
// routes/userRoutes.js
router.put('/users/:userId/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const { fcmToken } = req.body;

    await User.findByIdAndUpdate(userId, { fcmToken });

    res.status(200).json({ message: 'FCM Token registered successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error registering FCM token', error: error.message });
  }
});
*/

// 5. دالة إرسال إشعار FCM:
async function sendFCMNotification(userFCMToken, title, body, data = {}) {
  if (!userFCMToken) {
    console.log('⚠️ No FCM token found for user');
    return;
  }

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      ...data,
      // تحويل جميع القيم إلى strings (مطلوب من FCM)
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    token: userFCMToken,
    android: {
      priority: 'high',
      notification: {
        sound: 'default', // ✅ صوت الإشعار
        channelId: 'shaqati_messages',
        priority: 'high',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default', // ✅ صوت الإشعار على iOS
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ FCM notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
    return { success: false, error: error.message };
  }
}

// 6. استخدام الدالة في chatController.js:
/*
// controllers/chatController.js
import { sendFCMNotification } from '../utils/fcmHelper.js';
import User from '../models/User.js';

export const sendMessage = async (req, res) => {
  try {
    const { receiverId, message, attachments } = req.body;
    const senderId = req.user._id;

    // حفظ الرسالة في قاعدة البيانات
    const newMessage = new Chat({
      senderId,
      receiverId,
      message,
      attachments,
      isRead: false,
    });
    await newMessage.save();

    // جلب معلومات المستقبل
    const receiver = await User.findById(receiverId);
    
    // إرسال إشعار FCM إذا كان لديه token
    if (receiver?.fcmToken) {
      await sendFCMNotification(
        receiver.fcmToken,
        `📩 رسالة جديدة من ${req.user.name}`,
        message.length > 50 ? message.substring(0, 50) + '...' : message,
        {
          type: 'chat',
          senderId: senderId.toString(),
          receiverId: receiverId.toString(),
          chatId: newMessage._id.toString(),
          message: message,
        }
      );
    }

    res.status(201).json({
      message: '✅ Message sent successfully',
      data: newMessage,
    });
  } catch (error) {
    res.status(500).json({ message: '❌ Error sending message', error: error.message });
  }
};
*/

// 7. إرسال إشعارات متعددة (لإشعارات عامة):
async function sendFCMNotificationToMultipleUsers(userFCMTokens, title, body, data = {}) {
  if (!userFCMTokens || userFCMTokens.length === 0) {
    console.log('⚠️ No FCM tokens found');
    return;
  }

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'shaqati_messages',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
    tokens: userFCMTokens, // قائمة من tokens
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Sent ${response.successCount} notifications successfully`);
    console.log(`❌ Failed ${response.failureCount} notifications`);
    return response;
  } catch (error) {
    console.error('❌ Error sending multicast FCM notifications:', error);
    return { success: false, error: error.message };
  }
}

// 8. Export الدوال:
module.exports = {
  sendFCMNotification,
  sendFCMNotificationToMultipleUsers,
};

// ============================================
// 📝 ملاحظات مهمة:
// ============================================
// 1. Service Account Key يجب أن يكون في .gitignore
// 2. تأكد من أن FCM Token يتم تحديثه عند تسجيل الدخول
// 3. يمكنك إرسال إشعارات عند أي حدث (عقد جديد، دفعة، صيانة، إلخ)
// 4. الصوت سيعمل تلقائياً إذا كان sound: 'default'
// 5. يمكنك استخدام مواضيع (Topics) لإرسال إشعارات جماعية

