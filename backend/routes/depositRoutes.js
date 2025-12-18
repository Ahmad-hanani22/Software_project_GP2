import express from "express";
import {
  addDeposit,
  getDepositByContract,
  updateDeposit,
  getAllDeposits,
} from "../controllers/depositController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة تأمين (مالك أو أدمن)
router.post("/", authorizeRoles("landlord", "admin"), addDeposit);

// 2. جلب جميع التأمينات
router.get("/", getAllDeposits);

// 3. جلب تأمين عقد معين
router.get("/contract/:contractId", getDepositByContract);

// 4. تحديث تأمين (استقطاع أو استرداد)
router.put("/:id", authorizeRoles("landlord", "admin"), updateDeposit);

export default router;

