import express from "express";
import {
  addUnit,
  getAllUnits,
  getUnitById,
  getUnitsByProperty,
  updateUnit,
  deleteUnit,
  getUnitStats,
} from "../controllers/unitController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

// جميع المسارات محمية
router.use(protect);

// 1. إنشاء وحدة جديدة (مالك أو أدمن)
router.post("/", authorizeRoles("landlord", "admin"), addUnit);

// 2. جلب جميع الوحدات (مع إمكانية التصفية)
router.get("/", getAllUnits);

// 3. جلب وحدة محددة
router.get("/:id", getUnitById);

// 4. جلب وحدات عقار معين
router.get("/property/:propertyId", getUnitsByProperty);

// 5. جلب إحصائيات وحدة
router.get("/:id/stats", getUnitStats);

// 6. تحديث وحدة (مالك أو أدمن)
router.put("/:id", authorizeRoles("landlord", "admin"), updateUnit);

// 7. حذف وحدة (مالك أو أدمن)
router.delete("/:id", authorizeRoles("landlord", "admin"), deleteUnit);

export default router;

