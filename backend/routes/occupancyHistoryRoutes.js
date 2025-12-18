import express from "express";
import {
  addOccupancyHistory,
  getOccupancyByUnit,
  getOccupancyByTenant,
  updateOccupancyHistory,
  getAllOccupancyHistory,
} from "../controllers/occupancyHistoryController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة سجل إشغال (عادة يتم تلقائياً عند تفعيل عقد)
router.post("/", authorizeRoles("landlord", "admin"), addOccupancyHistory);

// 2. جلب جميع سجلات الإشغال (أدمن فقط)
router.get("/", authorizeRoles("admin"), getAllOccupancyHistory);

// 3. جلب سجل إشغال وحدة معينة
router.get("/unit/:unitId", getOccupancyByUnit);

// 4. جلب سجل إشغال مستأجر معين
router.get("/tenant/:tenantId", getOccupancyByTenant);

// 5. تحديث سجل إشغال (إنهاء الإشغال)
router.put("/:id", authorizeRoles("landlord", "admin"), updateOccupancyHistory);

export default router;

