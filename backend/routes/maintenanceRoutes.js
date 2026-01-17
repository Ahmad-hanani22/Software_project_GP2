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

router.post("/", protect, authorizeRoles("tenant"), createMaintenance);

router.get("/", protect, authorizeRoles("admin", "landlord"), getMaintenances);

router.get(
  "/tenant/:tenantId",
  protect,
  permitSelfOrAdmin("tenantId"),
  getTenantRequests
);

router.get(
  "/property/:propertyId",
  protect,
  ownsPropertyOrAdmin,
  getPropertyRequests
);

router.put(
  "/:id",
  protect,
  authorizeRoles("tenant", "landlord", "admin"),
  updateMaintenance
);

router.put(
  "/:id/assign",
  protect,
  authorizeRoles("landlord", "admin"),
  assignTechnician
);

router.put(
  "/:id/add-image",
  protect,
  authorizeRoles("tenant"),
  addImageToRequest
);

router.delete("/:id", protect, ownsMaintenanceOrAdmin, deleteMaintenance);

export default router;
