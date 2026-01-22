import express from "express";
import {
  addDeposit,
  getDepositByContract,
  updateDeposit,
  getAllDeposits,
  deleteDeposit,
} from "../controllers/depositController.js";

import {
  protect,
  authorizeRoles,
} from "../middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة تأمين (مالك، أدمن، أو مستأجر)
router.post("/", authorizeRoles("landlord", "admin", "tenant"), addDeposit);

// 2. جلب جميع التأمينات
router.get("/", getAllDeposits);

// 3. جلب تأمين عقد معين
router.get("/contract/:contractId", getDepositByContract);

// 4. تحديث تأمين (استقطاع أو استرداد) - مالك، أدمن، أو مستأجر
router.put("/:id", authorizeRoles("landlord", "admin", "tenant"), updateDeposit);

// 5. حذف تأمين - مالك، أدمن، أو مستأجر
router.delete("/:id", authorizeRoles("landlord", "admin", "tenant"), deleteDeposit);

export default router;

