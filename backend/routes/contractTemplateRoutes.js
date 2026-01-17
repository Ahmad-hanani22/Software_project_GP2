// routes/contractTemplateRoutes.js
import express from "express";
import {
  addContractTemplate,
  getAllContractTemplates,
  getContractTemplateById,
  updateContractTemplate,
  deleteContractTemplate,
  getDefaultContractTemplate,
} from "../controllers/contractTemplateController.js";

import { protect, authorizeRoles } from "../Middleware/authMiddleware.js";

const router = express.Router();

// 1. إنشاء قالب عقد جديد (Admin فقط)
router.post(
  "/",
  protect,
  authorizeRoles("admin"),
  addContractTemplate
);

// 2. جلب جميع قوالب العقود (Admin, Landlord, Tenant)
router.get("/", protect, getAllContractTemplates);

// 3. جلب القالب الافتراضي (Admin, Landlord, Tenant)
router.get("/default", protect, getDefaultContractTemplate);

// 4. جلب قالب عقد محدد (Admin, Landlord, Tenant)
router.get("/:id", protect, getContractTemplateById);

// 5. تحديث قالب عقد (Admin فقط)
router.put(
  "/:id",
  protect,
  authorizeRoles("admin"),
  updateContractTemplate
);

// 6. حذف قالب عقد (Admin فقط)
router.delete(
  "/:id",
  protect,
  authorizeRoles("admin"),
  deleteContractTemplate
);

export default router;
