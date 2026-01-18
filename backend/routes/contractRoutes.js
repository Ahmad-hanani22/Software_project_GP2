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
  signContract,
  uploadContractPdf,
  renewContract,
  requestTermination,
  getContractStatistics,
} from "../controllers/contractController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../middleware/authMiddleware.js";
import { isContractPartyOrAdmin, isContractPropertyOwner } from "../middleware/ownership.js";
import upload from "../middleware/uploadMiddleware.js";

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

// 4.1. إحصائيات العقد
router.get("/:id/statistics", protect, isContractPartyOrAdmin, getContractStatistics);

// 5. عرض عقود مستخدم معيّن
router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getContractsByUser
);

// 6. تحديث عقد (الموافقة عليه أو تعديله - لصاحب العقار فقط)
// ✅ صاحب العقار (property owner) هو من يوافق سواء كان landlord أو admin
router.put(
  "/:id",
  protect,
  isContractPropertyOwner,
  updateContract
);

// 7. حذف عقد (الأدمن فقط)
router.delete("/:id", protect, authorizeRoles("admin"), deleteContract);

// ✍️ توقيع إلكتروني للعقد (المالك أو المستأجر)
router.post(
  "/:id/sign",
  protect,
  isContractPartyOrAdmin,
  signContract
);

// 📄 رفع ملف PDF للعقد
router.post(
  "/:id/upload-pdf",
  protect,
  isContractPartyOrAdmin,
  upload.single("file"),
  uploadContractPdf
);

// 🔁 تجديد عقد
router.post(
  "/:id/renew",
  protect,
  isContractPartyOrAdmin,
  renewContract
);

// 🧨 طلب إنهاء عقد
router.post(
  "/:id/terminate",
  protect,
  isContractPartyOrAdmin,
  requestTermination
);

export default router;