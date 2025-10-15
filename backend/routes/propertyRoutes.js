import express from "express";
import {
  addProperty,
  getAllProperties,
  getPropertyById,
  getPropertiesByOwner,
  updateProperty,
  deleteProperty,
} from "../controllers/propertyController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../Middleware/authMiddleware.js";
import { ownsPropertyOrAdmin } from "../Middleware/ownership.js";

const router = express.Router();

/* 🔓 المسارات العامة (بدون تسجيل دخول) */
router.get("/", getAllProperties); // عرض كل العقارات
router.get("/:id", getPropertyById); // عرض عقار واحد بالتفصيل

/* 🔐 المسارات المحمية */
router.get(
  "/owner/:ownerId",
  protect,
  permitSelfOrAdmin("ownerId"),
  getPropertiesByOwner
); // عرض عقارات مالك (مالك نفسه أو أدمن فقط)

router.post("/", protect, authorizeRoles("landlord", "admin"), addProperty); // إضافة عقار (للأدمن أو المالك فقط)

router.put("/:id", protect, ownsPropertyOrAdmin, updateProperty); // تعديل العقار (صاحب العقار أو أدمن فقط)

router.delete("/:id", protect, ownsPropertyOrAdmin, deleteProperty); // حذف العقار (صاحب العقار أو أدمن فقط)

export default router;
