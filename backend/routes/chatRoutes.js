// routes/chatRoutes.js
import express from "express";
import {
  sendMessage,
  getConversation,
  getUserChats,
} from "../controllers/chatController.js";

import { protect, permitSelfOrAdmin } from "../Middleware/authMiddleware.js";

const router = express.Router();

/* =========================================================
 🔒 مسارات محمية
========================================================= */

// إرسال رسالة جديدة — فقط المستخدمين المسجلين
router.post("/", protect, sendMessage);

// عرض محادثة بين شخصين — فقط أحد الطرفين أو الأدمن
router.get("/:user1/:user2", protect, getConversation);

// عرض كل المحادثات الخاصة بمستخدم — فقط نفسه أو أدمن
router.get("/user/:userId", protect, permitSelfOrAdmin("userId"), getUserChats);

export default router;
