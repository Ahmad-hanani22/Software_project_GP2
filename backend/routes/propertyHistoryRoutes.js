import express from "express";
import {
  addPropertyHistory,
  getPropertyHistory,
  getAllPropertyHistory,
} from "../controllers/propertyHistoryController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة سجل تاريخ (عادة تلقائي)
router.post("/", authorizeRoles("landlord", "admin"), addPropertyHistory);

// 2. جلب تاريخ عقار معين
router.get("/property/:propertyId", getPropertyHistory);

// 3. جلب جميع السجلات (أدمن فقط)
router.get("/", authorizeRoles("admin"), getAllPropertyHistory);

export default router;

