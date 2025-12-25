# 🔔 دليل إعداد Firebase Cloud Messaging (FCM) - خطوات مفصلة

## 📋 الخطوات المطلوبة منك

### ✅ الخطوة 1: إنشاء مشروع Firebase

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اضغط على **"Add project"** أو **"إضافة مشروع"**
3. أدخل اسم المشروع: `SHAQATI` (أو أي اسم تريده)
4. اضغط **Continue** ثم **Create project**
5. انتظر حتى يتم إنشاء المشروع

---

### ✅ الخطوة 2: إضافة تطبيق Android إلى Firebase

1. في صفحة المشروع، اضغط على أيقونة **Android** (أو **Add app** → **Android**)
2. أدخل:
   - **Android package name**: `com.example.flutter_application_1`
     (يمكنك التحقق من هذا في `android/app/build.gradle.kts` في `applicationId`)
   - **App nickname**: `SHAQATI Android` (اختياري)
   - **Debug signing certificate SHA-1**: (اختياري - يمكنك تخطيه الآن)
3. اضغط **Register app**
4. **تحميل ملف `google-services.json`**:
   - سيطلب منك Firebase تحميل ملف `google-services.json`
   - **احفظ هذا الملف** في مكان آمن
   - انسخه إلى: `flutter_application_1/android/app/google-services.json`
     (يجب أن يكون المسار: `android/app/google-services.json`)

---

### ✅ الخطوة 3: إضافة تطبيق iOS إلى Firebase

1. في صفحة المشروع، اضغط على أيقونة **iOS** (أو **Add app** → **iOS**)
2. أدخل:
   - **iOS bundle ID**: يمكنك العثور عليه في `ios/Runner.xcodeproj/project.pbxproj`
     أو في Xcode → Runner → General → Bundle Identifier
     (عادة يكون مثل: `com.example.flutterApplication1`)
   - **App nickname**: `SHAQATI iOS` (اختياري)
3. اضغط **Register app**
4. **تحميل ملف `GoogleService-Info.plist`**:
   - سيطلب منك Firebase تحميل ملف `GoogleService-Info.plist`
   - **احفظ هذا الملف** في مكان آمن
   - افتح Xcode: `flutter_application_1/ios/Runner.xcworkspace`
   - اسحب ملف `GoogleService-Info.plist` إلى مجلد `Runner` في Xcode
   - تأكد من تحديد **"Copy items if needed"** و **"Runner"** في Target Membership

---

### ✅ الخطوة 4: تفعيل Cloud Messaging API

1. في Firebase Console، اذهب إلى **Project Settings** (⚙️)
2. اضغط على تبويب **Cloud Messaging**
3. تأكد من أن **Cloud Messaging API (Legacy)** مفعل
4. إذا لم يكن مفعلاً، اضغط على **Enable**

---

### ✅ الخطوة 5: الحصول على Server Key (للباك إند)

1. في Firebase Console، اذهب إلى **Project Settings** (⚙️)
2. اضغط على تبويب **Cloud Messaging**
3. ابحث عن **"Cloud Messaging API (Legacy)"** → **Server key**
4. انسخ **Server key** واحفظه (ستحتاجه في الباك إند)

---

### ✅ الخطوة 6: تحديث الباك إند (Backend)

يجب عليك إضافة endpoint في الباك إند لتسجيل FCM Token:

#### 6.1: إضافة Route في Backend

```javascript
// routes/userRoutes.js أو routes/authRoutes.js
router.put('/users/:userId/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const { fcmToken } = req.body;

    // تحديث FCM Token في قاعدة البيانات
    await User.findByIdAndUpdate(userId, { fcmToken });

    res.status(200).json({ message: 'FCM Token registered successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error registering FCM token', error: error.message });
  }
});
```

#### 6.2: إضافة FCM Token إلى User Model

```javascript
// models/User.js
const userSchema = new Schema({
  // ... باقي الحقول
  fcmToken: {
    type: String,
    default: null,
  },
});
```

#### 6.3: إرسال إشعارات عند وصول رسالة

في `backend/controllers/chatController.js` أو `backend/utils/sendNotification.js`:

```javascript
const admin = require('firebase-admin');

// تهيئة Firebase Admin SDK (مرة واحدة في بداية التطبيق)
if (!admin.apps.length) {
  const serviceAccount = require('./path/to/serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// إرسال إشعار FCM عند وصول رسالة
async function sendFCMNotification(userFCMToken, title, body, data = {}) {
  if (!userFCMToken) return;

  const message = {
  
    notification: {
      title: title,
      body: body,
    },
    data: data,
    token: userFCMToken,
    android: {
      priority: 'high',
      notification: {
        sound: 'default', // ✅ صوت الإشعار
        channelId: 'shaqati_messages',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default', // ✅ صوت الإشعار على iOS
        },
      },
    },
  };

  try {
    await admin.messaging().send(message);
    console.log('✅ FCM notification sent successfully');
  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
  }
}

// استخدامها في chatController.js
export const sendMessage = async (req, res) => {
  // ... الكود الحالي
  
  // إرسال إشعار FCM
  const receiver = await User.findById(receiverId);
  if (receiver?.fcmToken) {
    await sendFCMNotification(
      receiver.fcmToken,
      `📩 رسالة جديدة من ${req.user.name}`,
      message.substring(0, 50),
      {
        type: 'chat',
        senderId: senderId.toString(),
        receiverId: receiverId.toString(),
        chatId: newMessage._id.toString(),
      }
    );
  }
  
  // ... باقي الكود
};
```

#### 6.4: الحصول على Service Account Key

1. في Firebase Console، اذهب إلى **Project Settings** (⚙️)
2. اضغط على تبويب **Service accounts**
3. اضغط **Generate new private key**
4. احفظ الملف في `backend/config/serviceAccountKey.json`
5. **⚠️ مهم**: أضف `serviceAccountKey.json` إلى `.gitignore` (لا ترفعه على GitHub!)

---

### ✅ الخطوة 7: تثبيت Dependencies

في مجلد المشروع Flutter:

```bash
cd flutter_application_1
flutter pub get
```

---

### ✅ الخطوة 8: بناء التطبيق

#### Android:
```bash
flutter build apk
# أو
flutter run
```

#### iOS:
```bash
cd ios
pod install
cd ..
flutter run
```

---

## 🧪 اختبار الإشعارات

### 1. اختبار من Firebase Console:

1. اذهب إلى Firebase Console → **Cloud Messaging**
2. اضغط **Send your first message**
3. أدخل:
   - **Notification title**: `Test Notification`
   - **Notification text**: `This is a test message`
4. اضغط **Send test message**
5. أدخل FCM Token (يمكنك الحصول عليه من logs التطبيق)
6. اضغط **Test**

### 2. اختبار من الباك إند:

عند إرسال رسالة من تطبيق آخر، يجب أن يصل إشعار تلقائياً.

---

## 📝 ملاحظات مهمة

1. **الصوت**: الإشعارات ستشغل الصوت تلقائياً من خلال نظام الإشعارات
2. **Android**: تأكد من أن `google-services.json` موجود في `android/app/`
3. **iOS**: تأكد من أن `GoogleService-Info.plist` موجود في `ios/Runner/`
4. **Permissions**: التطبيق سيطلب صلاحيات الإشعارات عند أول تشغيل
5. **FCM Token**: يتم حفظه تلقائياً وإرساله للباك إند عند تسجيل الدخول

---

## 🔧 استكشاف الأخطاء

### المشكلة: الإشعارات لا تصل
- ✅ تأكد من أن `google-services.json` موجود في المكان الصحيح
- ✅ تأكد من أن FCM Token مسجل في الباك إند
- ✅ تأكد من أن صلاحيات الإشعارات مفعلة
- ✅ تحقق من logs التطبيق

### المشكلة: الصوت لا يعمل
- ✅ تأكد من أن الصوت مفعل في إعدادات الجهاز
- ✅ تأكد من أن التطبيق لديه صلاحيات الإشعارات
- ✅ على Android، تأكد من أن `playSound: true` في Notification Channel

---

## ✅ تم! 🎉

بعد إكمال جميع الخطوات، الإشعارات ستصل تلقائياً مع الصوت عند:
- وصول رسالة جديدة
- أي حدث آخر يرسل إشعار من الباك إند

---

## 📞 الدعم

إذا واجهت أي مشكلة، تحقق من:
- [Firebase Documentation](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire Documentation](https://firebase.flutter.dev/docs/messaging/overview)

