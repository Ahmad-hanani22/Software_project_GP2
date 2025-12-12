import express from "express";
import {
  registerUser,
  loginUser,
  verifyUserEmail,
  getMe,
} from "../controllers/userController.js";
import { protect } from "../Middleware/authMiddleware.js";

const router = express.Router();

/* =========================
   AUTH ROUTES
========================= */

// إنشاء حساب + إرسال إيميل التفعيل
router.post("/register", registerUser);

// تسجيل الدخول (ممنوع إذا الإيميل غير مفعّل)
router.post("/login", loginUser);

// تفعيل الإيميل
router.get("/verify/:token", verifyUserEmail);

/* =========================
   USER ROUTES
========================= */

// جلب بيانات المستخدم الحالي
router.get("/me", protect, getMe);

export default router;
