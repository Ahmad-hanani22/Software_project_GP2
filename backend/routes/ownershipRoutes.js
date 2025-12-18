import express from "express";
import {
  addOwnership,
  getPropertyOwnership,
  getOwnerProperties,
  updateOwnership,
  deleteOwnership,
} from "../controllers/ownershipController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة ملكية
router.post("/", authorizeRoles("landlord", "admin"), addOwnership);

// 2. جلب ملكيات عقار معين
router.get("/property/:propertyId", getPropertyOwnership);

// 3. جلب عقارات مالك معين
router.get("/owner/:ownerId", getOwnerProperties);

// 4. تحديث ملكية
router.put("/:id", authorizeRoles("landlord", "admin"), updateOwnership);

// 5. حذف ملكية
router.delete("/:id", authorizeRoles("landlord", "admin"), deleteOwnership);

export default router;

