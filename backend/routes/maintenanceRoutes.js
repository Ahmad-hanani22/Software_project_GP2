import express from "express";
import {
  createMaintenance,
  getMaintenances,
  getTenantRequests,
  getPropertyRequests,
  updateMaintenance,
  assignTechnician,
  addImageToRequest,
  deleteMaintenance,
} from "../controllers/maintenanceController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../Middleware/authMiddleware.js";

import {
  ownsPropertyOrAdmin,
  ownsMaintenanceOrAdmin,
} from "../Middleware/ownership.js";

const router = express.Router();

/* 🧾 الصيانة */

// 🟢 إنشاء طلب صيانة (Tenant فقط)
router.post("/", protect, authorizeRoles("tenant"), createMaintenance);

// 🟡 عرض كل الطلبات (Admin فقط)
router.get("/", protect, authorizeRoles("admin"), getMaintenances);

// 🧍‍♂️ عرض طلبات الصيانة الخاصة بمستأجر معيّن (نفسه أو أدمن)
router.get(
  "/tenant/:tenantId",
  protect,
  permitSelfOrAdmin("tenantId"),
  getTenantRequests
);

// 🏠 عرض طلبات صيانة لعقار (مالك العقار أو أدمن)
router.get(
  "/property/:propertyId",
  protect,
  ownsPropertyOrAdmin,
  getPropertyRequests
);

// 🔧 تحديث حالة الطلب (Landlord أو Admin)
router.put(
  "/:id",
  protect,
  authorizeRoles("landlord", "admin"),
  updateMaintenance
);

// 👷 تعيين فني (Landlord أو Admin)
router.put(
  "/:id/assign",
  protect,
  authorizeRoles("landlord", "admin"),
  assignTechnician
);

// 🖼️ إضافة صورة (Tenant فقط)
router.put(
  "/:id/add-image",
  protect,
  authorizeRoles("tenant"),
  addImageToRequest
);

// ❌ حذف الطلب (مالك الطلب أو أدمن)
router.delete("/:id", protect, ownsMaintenanceOrAdmin, deleteMaintenance);

export default router;
