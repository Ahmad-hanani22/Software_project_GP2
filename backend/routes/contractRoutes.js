// routes/contractRoutes.js
import express from "express";
import {
  addContract,
  requestContract, // ✅ استيراد دالة الطلب
  getAllContracts,
  getContractById,
  getContractsByUser,
  updateContract,
  deleteContract,
} from "../controllers/contractController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../Middleware/authMiddleware.js";
import { isContractPartyOrAdmin } from "../Middleware/ownership.js";

const router = express.Router();

// 1. عرض كل العقود (أدمن فقط)
router.get("/", protect, authorizeRoles("admin"), getAllContracts);

// 2. إضافة عقد مباشرة (للمالك والأدمن)
router.post(
  "/",
  protect,
  authorizeRoles("landlord", "admin"), // عادة المالك أو الأدمن ينشئ العقد المباشر
  addContract
);

// 3. ✅ طلب عقد (للمستأجر) - هذا هو المسار الجديد لزر Rent Now
router.post("/request", protect, authorizeRoles("tenant"), requestContract);

// 4. عرض عقد واحد (يخص المستأجر أو المالك أو الأدمن)
router.get("/:id", protect, isContractPartyOrAdmin, getContractById);

// 5. عرض عقود مستخدم معيّن
router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getContractsByUser
);

// 6. تحديث عقد (الموافقة عليه أو تعديله - للمالك أو الأدمن)
router.put(
  "/:id",
  protect,
  authorizeRoles("landlord", "admin"),
  isContractPartyOrAdmin,
  updateContract
);

// 7. حذف عقد (الأدمن فقط)
router.delete("/:id", protect, authorizeRoles("admin"), deleteContract);

export default router;