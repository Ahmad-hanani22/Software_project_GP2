import Notification from "../models/Notification.js";
import User from "../models/User.js";
import { io } from "../server.js";

/* =========================================================
 📩 دالة إرسال إشعار (النسخة المصححة - تدعم مصفوفة recipients)
========================================================= */
export const sendNotification = async (notificationData = {}) => {
  try {
    // 1. التحقق من المستلمين
    if (
      !notificationData.recipients ||
      !Array.isArray(notificationData.recipients) ||
      notificationData.recipients.length === 0
    ) {
      console.warn("⚠️ Skipping notification: recipients list is empty");
      return;
    }

    // 2. تجهيز البيانات للحفظ في الداتابيس (تحويل المصفوفة إلى عدة صفوف)
    const notificationsToInsert = notificationData.recipients.map((recipientId) => ({
      userId: recipientId, 
      message: notificationData.message,
      title: notificationData.title,
      type: notificationData.type || "system",
      actorId: notificationData.actorId,
      entityType: notificationData.entityType,
      entityId: notificationData.entityId,
      link: notificationData.link,
      isRead: false,
      createdAt: new Date(),
    }));

    // 3. الحفظ الجماعي في الداتابيس
    const createdNotifications = await Notification.insertMany(notificationsToInsert);

    // 4. البث الفوري عبر Socket.IO
    // نستخدم حلقة تكرار لإرسال الإشعار لكل شخص في غرفته الخاصة
    createdNotifications.forEach((notif) => {
      if (io) {
        io.to(String(notif.userId)).emit("new_notification", notif);
      }
    });

    console.log(
      `📨 Notification sent & saved for ${createdNotifications.length} user(s).`
    );

    return createdNotifications;
  } catch (error) {
    console.error("❌ Error in sendNotification function:", error);
  }
};

/* =========================================================
 🧠 دالة لمراسلة مستخدم واحد فقط (Helper)
========================================================= */
export const sendNotificationToUser = async ({ userId, title, message, ...extra }) => {
  try {
    if (!userId) {
      console.error("❌ Skipping notification: userId is missing");
      return;
    }

    const notificationData = {
      recipients: [userId], // نحوله لمصفوفة ليعمل مع الدالة الرئيسية
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
 🧠 دالة لمراسلة جميع الأدمنز (notifyAdmins)
========================================================= */
export const notifyAdmins = async (notificationData = {}) => {
  try {
    const { message, title, ...extraData } = notificationData;

    // التحقق من النص
    if (!message || typeof message !== "string") {
      console.error("❌ Error notifying admins: 'message' is missing or invalid.");
      return;
    }

    // جلب كل الأدمنز
    const admins = await User.find({ role: "admin" }).select("_id").lean();
    const adminIds = admins.map((a) => a._id);

    if (adminIds.length === 0) {
      console.log("📢 No admins found to notify.");
      return;
    }

    // تجهيز البيانات
    const finalNotificationData = {
      recipients: adminIds,
      title: title || "إشعار إداري جديد",
      message,
      type: extraData.type || "system",
      ...extraData,
    };

    // استدعاء الدالة الرئيسية
    await sendNotification(finalNotificationData);

    console.log(`📢 Broadcasted to ${adminIds.length} admins`);
  } catch (error) {
    console.error("❌ Error in notifyAdmins function:", error);
  }
};