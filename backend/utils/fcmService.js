// utils/fcmService.js
// 🔔 خدمة إرسال إشعارات Firebase Cloud Messaging

import admin from "firebase-admin";
import User from "../models/User.js";
import { readFileSync } from "fs";
import { fileURLToPath, pathToFileURL } from "url";
import { dirname, join } from "path";

// تهيئة Firebase Admin (مرة واحدة)
let firebaseInitialized = false;

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const initializeFirebase = async () => {
  if (firebaseInitialized) {
    return;
  }

  try {
    let serviceAccount;
    const firebaseJsPath = join(__dirname, "../config/firebase.js");
    const serviceAccountJsonPath = join(__dirname, "../config/serviceAccountKey.json");
    
    // الخيار 1️⃣: محاولة تحميل من firebase.js (إذا كان موجوداً)
    // firebase.js قد يستورد serviceAccountKey.json أو يحتوي على البيانات مباشرة
    try {
      const firebaseJsUrl = pathToFileURL(firebaseJsPath).href;
      const firebaseConfig = await import(firebaseJsUrl);
      
      // firebase.js قد يصدر serviceAccount مباشرة أو admin initialized
      serviceAccount = firebaseConfig.default || firebaseConfig.serviceAccount;
      
      // إذا كان firebase.js يقوم بالتهيئة بنفسه (admin initialized)
      if (firebaseConfig.admin && admin.apps.length > 0) {
        firebaseInitialized = true;
        console.log("✅ Firebase Admin initialized via firebase.js");
        return;
      }
      
      if (!serviceAccount) {
        throw new Error("firebase.js does not export serviceAccount");
      }
      
      console.log("✅ Loaded Firebase config from firebase.js");
    } catch (jsError) {
      // الخيار 2️⃣: إذا فشل firebase.js، جرب serviceAccountKey.json مباشرة
      try {
        serviceAccount = JSON.parse(readFileSync(serviceAccountJsonPath, "utf8"));
        console.log("✅ Loaded Firebase config from serviceAccountKey.json");
      } catch (jsonError) {
        // إذا فشل كلاهما
        console.error("❌ Could not load Firebase config:");
        if (jsError.code !== "MODULE_NOT_FOUND") {
          console.error(`   - firebase.js: ${jsError.message}`);
        } else {
          console.error(`   - firebase.js: File not found`);
        }
        if (jsonError.code !== "ENOENT") {
          console.error(`   - serviceAccountKey.json: ${jsonError.message}`);
        } else {
          console.error(`   - serviceAccountKey.json: File not found`);
        }
        throw new Error("Firebase config files not found");
      }
    }

    // تهيئة Firebase Admin
    if (!admin.apps.length && serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      firebaseInitialized = true;
      console.log("✅ Firebase Admin initialized successfully");
    }
  } catch (error) {
    console.error("❌ Error initializing Firebase Admin:", error.message);
    console.warn("⚠️ FCM notifications will be disabled.");
    console.warn("⚠️ Please add one of:");
    console.warn("   1. backend/config/firebase.js (preferred)");
    console.warn("   2. backend/config/serviceAccountKey.json");
  }
};

// تهيئة Firebase عند تحميل الملف (async)
initializeFirebase().catch(() => {
  // Silent fail - سيتم إعادة المحاولة عند أول استخدام
});

/* =========================================================
   🔔 إرسال إشعار FCM لمستخدم واحد
========================================================= */
export const sendFCMNotification = async (userFCMToken, title, body, data = {}) => {
  if (!firebaseInitialized || !userFCMToken) {
    return { success: false, error: "FCM not initialized or token missing" };
  }

  const message = {
    notification: {
      title: title || "SHAQATI",
      body: body || "",
    },
    data: {
      ...data,
      // تحويل جميع القيم إلى strings (مطلوب من FCM)
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    token: userFCMToken,
    android: {
      priority: "high",
      notification: {
        sound: "default", // ✅ صوت الإشعار
        channelId: "shaqati_messages",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default", // ✅ صوت الإشعار على iOS
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`✅ FCM notification sent successfully: ${response}`);
    return { success: true, messageId: response };
  } catch (error) {
    console.error("❌ Error sending FCM notification:", error);
    return { success: false, error: error.message };
  }
};

/* =========================================================
   🔔 إرسال إشعار FCM لمستخدمين متعددين
========================================================= */
export const sendFCMNotificationToMultiple = async (userFCMTokens, title, body, data = {}) => {
  if (!firebaseInitialized || !userFCMTokens || userFCMTokens.length === 0) {
    return { success: false, error: "FCM not initialized or tokens missing" };
  }

  const message = {
    notification: {
      title: title || "SHAQATI",
      body: body || "",
    },
    data: {
      ...data,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        sound: "default",
        channelId: "shaqati_messages",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
    tokens: userFCMTokens.filter((token) => token && token.trim() !== ""), // إزالة tokens فارغة
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ Sent ${response.successCount} FCM notifications`);
    if (response.failureCount > 0) {
      console.warn(`⚠️ Failed to send ${response.failureCount} notifications`);
    }
    return { success: true, response };
  } catch (error) {
    console.error("❌ Error sending multicast FCM notifications:", error);
    return { success: false, error: error.message };
  }
};

/* =========================================================
   🔔 إرسال إشعار FCM بناءً على User ID
========================================================= */
export const sendFCMNotificationByUserId = async (userId, title, body, data = {}) => {
  try {
    const user = await User.findById(userId).select("fcmToken name");
    if (!user || !user.fcmToken) {
      console.log(`⚠️ User ${userId} has no FCM token`);
      return { success: false, error: "No FCM token found" };
    }

    return await sendFCMNotification(user.fcmToken, title, body, data);
  } catch (error) {
    console.error("❌ Error in sendFCMNotificationByUserId:", error);
    return { success: false, error: error.message };
  }
};

/* =========================================================
   🔔 إرسال إشعار FCM لعدة مستخدمين بناءً على User IDs
========================================================= */
export const sendFCMNotificationByUserIds = async (userIds, title, body, data = {}) => {
  try {
    const users = await User.find({ _id: { $in: userIds } })
      .select("fcmToken")
      .lean();

    const fcmTokens = users
      .map((user) => user.fcmToken)
      .filter((token) => token && token.trim() !== "");

    if (fcmTokens.length === 0) {
      console.log("⚠️ No FCM tokens found for the provided user IDs");
      return { success: false, error: "No FCM tokens found" };
    }

    return await sendFCMNotificationToMultiple(fcmTokens, title, body, data);
  } catch (error) {
    console.error("❌ Error in sendFCMNotificationByUserIds:", error);
    return { success: false, error: error.message };
  }
};

/* =========================================================
   🔔 إرسال إشعار FCM لجميع الأدمنز
========================================================= */
export const sendFCMNotificationToAdmins = async (title, body, data = {}) => {
  try {
    const admins = await User.find({ role: "admin" })
      .select("fcmToken")
      .lean();

    const fcmTokens = admins
      .map((admin) => admin.fcmToken)
      .filter((token) => token && token.trim() !== "");

    if (fcmTokens.length === 0) {
      console.log("⚠️ No admins with FCM tokens found");
      return { success: false, error: "No admin FCM tokens found" };
    }

    return await sendFCMNotificationToMultiple(fcmTokens, title, body, data);
  } catch (error) {
    console.error("❌ Error in sendFCMNotificationToAdmins:", error);
    return { success: false, error: error.message };
  }
};

/* =========================================================
   🔔 إرسال إشعار FCM لجميع الملاك
========================================================= */
export const sendFCMNotificationToLandlords = async (title, body, data = {}) => {
  try {
    const landlords = await User.find({ role: "landlord" })
      .select("fcmToken")
      .lean();

    const fcmTokens = landlords
      .map((landlord) => landlord.fcmToken)
      .filter((token) => token && token.trim() !== "");

    if (fcmTokens.length === 0) {
      console.log("⚠️ No landlords with FCM tokens found");
      return { success: false, error: "No landlord FCM tokens found" };
    }

    return await sendFCMNotificationToMultiple(fcmTokens, title, body, data);
  } catch (error) {
    console.error("❌ Error in sendFCMNotificationToLandlords:", error);
    return { success: false, error: error.message };
  }
};

/* =========================================================
   🔔 إرسال إشعار FCM لجميع المستأجرين
========================================================= */
export const sendFCMNotificationToTenants = async (title, body, data = {}) => {
  try {
    const tenants = await User.find({ role: "tenant" })
      .select("fcmToken")
      .lean();

    const fcmTokens = tenants
      .map((tenant) => tenant.fcmToken)
      .filter((token) => token && token.trim() !== "");

    if (fcmTokens.length === 0) {
      console.log("⚠️ No tenants with FCM tokens found");
      return { success: false, error: "No tenant FCM tokens found" };
    }

    return await sendFCMNotificationToMultiple(fcmTokens, title, body, data);
  } catch (error) {
    console.error("❌ Error in sendFCMNotificationToTenants:", error);
    return { success: false, error: error.message };
  }
};

