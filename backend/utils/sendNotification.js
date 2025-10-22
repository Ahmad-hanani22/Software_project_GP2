// file: backend/utils/sendNotification.js

import Notification from "../models/Notification.js";
import User from "../models/User.js"; // تأكد من أن مسار موديل المستخدم صحيح
import { io } from "../server.js";

/* =========================================================
 📩 دالة إرسال إشعار (وتخزينه + بثه فورًا)
========================================================= */
// ملاحظة: تم تحسين هذه الدالة لتتعامل مع مصفوفة من المستلمين
export const sendNotification = async (notificationData) => {
  try {
    // التحقق من وجود مستلمين
    if (!notificationData.recipients || notificationData.recipients.length === 0) {
      console.log("⚠️ Notification has no recipients. Skipping.");
      return;
    }

    const notification = new Notification(notificationData);
    await notification.save();

    // جلب البيانات المضمنة (populate) بعد الحفظ مباشرة
    const populatedNotification = await Notification.findById(notification._id)
      .populate("actorId", "name role")
      .populate("entityId");

    // 🔔 بث الإشعار مباشرة لكل مستلم عبر Socket.IO
    for (const recipientId of notification.recipients) {
      io.to(String(recipientId)).emit("new_notification", populatedNotification);
    }

    console.log(
      `📨 Notification sent to ${notification.recipients.length} user(s): ${notification.message}`
    );

    return populatedNotification;
  } catch (error) {
    console.error("❌ Error in sendNotification function:", error);
  }
};


/* =========================================================
 🧠 دالة لمراسلة جميع الأدمنز (النسخة النهائية والمعدلة)
========================================================= */
/**
 * @param {object} notificationData - كائن يحتوي على كل تفاصيل الإشعار
 *        مثال: { message: 'نص الرسالة', link: '/path', actorId: '...' }
 */
export const notifyAdmins = async (notificationData = {}) => {
  try {
    // ✅ الحل موجود هنا: نستخلص الرسالة وبقية البيانات من الكائن
    const { message, ...extraData } = notificationData;

    // التحقق من أن الرسالة موجودة وهي نص
    if (!message || typeof message !== 'string') {
      console.error("❌ Error notifying admins: 'message' is missing or not a string in notificationData.");
      return;
    }

    // البحث عن كل المستخدمين الذين لهم دور "admin"
    const admins = await User.find({ role: "admin" }).select("_id").lean();
    const adminIds = admins.map(admin => admin._id);

    if (adminIds.length === 0) {
      console.log("📢 No admins found to notify.");
      return;
    }
    
    // بناء الكائن النهائي للإشعار
    const finalNotificationData = {
      recipients: adminIds, // إرسال لجميع الأدمنز
      message,              // الرسالة النصية
      type: "system",        // نوع إشعار النظام (يمكن تغييره إذا تم تمريره)
      ...extraData,         // دمج بقية البيانات (link, actorId, etc.)
    };

    // استدعاء الدالة الأساسية لإرسال الإشعار
    await sendNotification(finalNotificationData);

    console.log(`📢 Broadcasted to ${adminIds.length} admins`);
  } catch (error) {
    console.error("❌ Error in notifyAdmins function:", error);
  }
};