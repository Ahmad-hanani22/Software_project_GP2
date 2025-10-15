import Notification from "../models/Notification.js";
import { io } from "../server.js"; // 👈 استيراد الـ io من السيرفر

/* =========================================================
 📩 دالة إرسال إشعار (وتخزينه + بثه فورًا)
========================================================= */
export const sendNotification = async (data) => {
  try {
    // حفظ الإشعار في قاعدة البيانات
    const notification = new Notification(data);
    await notification.save();

    // 🔔 بث الإشعار مباشرة للمستخدم عبر Socket.IO
    io.to(String(notification.userId)).emit("new-notification", notification);

    console.log(
      `📨 Notification sent to user ${notification.userId}: ${notification.message}`
    );

    return notification;
  } catch (error) {
    console.error("❌ Error sending notification:", error);
  }
};

/* =========================================================
 🧠 دالة لمراسلة جميع الأدمنز
========================================================= */
export const notifyAdmins = async (message, extraData = {}) => {
  try {
    const admins = await Notification.db
      .model("User")
      .find({ role: "admin" })
      .select("_id");

    for (const admin of admins) {
      await sendNotification({
        userId: admin._id,
        message,
        type: "system",
        ...extraData,
      });
    }

    console.log(`📢 Broadcasted to ${admins.length} admins`);
  } catch (error) {
    console.error("❌ Error notifying admins:", error);
  }
};
