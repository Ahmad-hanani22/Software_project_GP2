import express from "express";
import {
  createNotification,
  sendDirectNotification, // ✅ تم إضافة الدالة الجديدة هنا
  getAllNotifications,
  getUserNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteNotification,
} from "../controllers/notificationController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../middleware/authMiddleware.js";

const router = express.Router();

// 📢 إرسال إشعار عام (لمجموعة أو للكل)
router.post("/", protect, authorizeRoles("admin", "tenant", "landlord"), createNotification);

// 📩 إرسال إشعار مباشر لشخص محدد (مهم جداً لطلبات الشراء/الإيجار لكي تصل للمالك فقط)
// ✅ هذا هو المسار الجديد
router.post("/direct", protect, authorizeRoles("admin", "tenant", "landlord"), sendDirectNotification);

// 🟣 عرض جميع الإشعارات (للأدمن فقط)
router.get("/", protect, authorizeRoles("admin"), getAllNotifications);

// 🔵 عرض إشعارات مستخدم معين (لنفسه أو للأدمن)
router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getUserNotifications
);

// 🟡 عرض عدد الإشعارات غير المقروءة
router.get(
  "/user/:userId/unread-count",
  protect,
  permitSelfOrAdmin("userId"),
  getUnreadCount
);

// ✉️ تحديد إشعار واحد كمقروء
router.put("/:id/read", protect, markAsRead);

// 📬 تحديد جميع الإشعارات كمقروءة
router.put(
  "/user/:userId/read-all",
  protect,
  permitSelfOrAdmin("userId"),
  markAllAsRead
);

// ❌ حذف إشعار (صاحبه أو الأدمن)
router.delete("/:id", protect, deleteNotification);

export default router;