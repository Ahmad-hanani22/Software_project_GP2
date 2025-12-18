import express from "express";
import {
  addBuilding,
  getAllBuildings,
  getBuildingById,
  updateBuilding,
  deleteBuilding,
} from "../controllers/buildingController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إنشاء مبنى (مالك أو أدمن)
router.post("/", authorizeRoles("landlord", "admin"), addBuilding);

// 2. جلب جميع المباني
router.get("/", getAllBuildings);

// 3. جلب مبنى محدد
router.get("/:id", getBuildingById);

// 4. تحديث مبنى (مالك أو أدمن)
router.put("/:id", authorizeRoles("landlord", "admin"), updateBuilding);

// 5. حذف مبنى (مالك أو أدمن)
router.delete("/:id", authorizeRoles("landlord", "admin"), deleteBuilding);

export default router;

