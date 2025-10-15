import express from "express";
import {
  createAdmin,
  getAllAdmins,
  updateAdmin,
  deleteAdmin,
  checkPermission,
} from "../controllers/adminController.js";

const router = express.Router();

// ➕ إنشاء أدمن
router.post("/", createAdmin);

// 📋 عرض جميع الأدمنز
router.get("/", getAllAdmins);

// ✏️ تحديث بيانات أدمن
router.put("/:id", updateAdmin);

// ❌ حذف أدمن
router.delete("/:id", deleteAdmin);

// 🔐 التحقق من الصلاحيات
router.post("/check-permission", checkPermission);

export default router;
