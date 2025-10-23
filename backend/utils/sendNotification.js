// =========================================================
// 📁 file: backend/utils/sendNotification.js
// =========================================================

import Notification from "../models/Notification.js";
import User from "../models/User.js"; // تأكد أن المسار صحيح
import { io } from "../server.js";

/* =========================================================
 📩 دالة إرسال إشعار (تخزين + بث فوري)
========================================================= */
/**
 * @param {object} notificationData - تفاصيل الإشعار
 * مثال:
 * {
 *   recipients: ['userId1', 'userId2'], // مصفوفة المستلمين
 *   title: 'تمت الموافقة على العقد',
 *   message: 'تمت الموافقة على عقد الإيجار الخاص بك',
 *   actorId: '64f...', // المستخدم الذي قام بالفعل
 *   entityId: '650...', // الكيان المرتبط (مثلاً عقد أو عقار)
 *   type: 'system' | 'contract' | 'payment' ...
 * }
 */
export const sendNotification = async (notificationData = {}) => {
  try {
    // ✅ التحقق من وجود المستلمين
    if (
      !notificationData.recipients ||
      !Array.isArray(notificationData.recipients) ||
      notificationData.recipients.length === 0
    ) {
      console.warn("⚠️ Skipping notification: recipients list is empty or invalid");
      return;
    }

    // ✅ إنشاء الإشعار وتخزينه
    const notification = await Notification.create({
      ...notificationData,
      read: false,
      createdAt: new Date(),
    });

    // ✅ بعد الحفظ، نجلب البيانات المفصلة عبر populate
    const populatedNotification = await Notification.findById(notification._id)
      .populate("actorId", "name role")
      .populate("entityId");

    // ✅ بث الإشعار فوراً لكل مستخدم مستهدف عبر Socket.IO
    for (const recipientId of notificationData.recipients) {
      io.to(String(recipientId)).emit("new_notification", populatedNotification);
    }

    console.log(
      `📨 Notification created & sent to ${notificationData.recipients.length} user(s): ${notificationData.message}`
    );

    return populatedNotification;
  } catch (error) {
    console.error("❌ Error in sendNotification function:", error);
  }
};

/* =========================================================
 🧠 دالة لمراسلة مستخدم واحد فقط (نسخة مبسطة)
========================================================= */
/**
 * ترسل إشعار لمستخدم واحد فقط عبر userId
 * مفيدة في الحالات البسيطة (مثل إشعار مستأجر أو مالك محدد)
 */
export const sendNotificationToUser = async ({ userId, title, message, ...extra }) => {
  try {
    if (!userId) {
      console.error("❌ Skipping notification: userId is missing");
      return;
    }

    const notificationData = {
      recipients: [userId],
      title,
      message,
      type: extra.type || "direct",
      ...extra,
    };

    return await sendNotification(notificationData);
  } catch (error) {
    console.error("❌ Error in sendNotificationToUser function:", error);
  }
};

/* =========================================================
 🧠 دالة لمراسلة جميع الأدمنز
========================================================= */
/**
 * ترسل إشعار لجميع الأدمنز المسجلين في النظام
 * @param {object} notificationData - تفاصيل الإشعار (message, link, actorId...)
 */
export const notifyAdmins = async (notificationData = {}) => {
  try {
    const { message, title, ...extraData } = notificationData;

    // ✅ التحقق من وجود الرسالة والنص
    if (!message || typeof message !== "string") {
      console.error("❌ Error notifying admins: 'message' is missing or invalid.");
      return;
    }

    // ✅ جلب جميع المستخدمين الذين دورهم "admin"
    const admins = await User.find({ role: "admin" }).select("_id").lean();
    const adminIds = admins.map((a) => a._id);

    if (adminIds.length === 0) {
      console.log("📢 No admins found to notify.");
      return;
    }

    // ✅ بناء البيانات النهائية للإشعار
    const finalNotificationData = {
      recipients: adminIds,
      title: title || "إشعار إداري جديد",
      message,
      type: extraData.type || "system",
      ...extraData,
    };

    await sendNotification(finalNotificationData);

    console.log(`📢 Broadcasted to ${adminIds.length} admins`);
  } catch (error) {
    console.error("❌ Error in notifyAdmins function:", error);
  }
};
