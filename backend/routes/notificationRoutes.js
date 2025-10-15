import express from "express";
import {
  createNotification,
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
} from "../Middleware/authMiddleware.js";

const router = express.Router();

/* =========================================================
 🔐 إشعارات (Notifications)
========================================================= */

// 🟢 إنشاء إشعار (يدوي) – فقط للأدمن
router.post("/", protect, authorizeRoles("admin"), createNotification);

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
