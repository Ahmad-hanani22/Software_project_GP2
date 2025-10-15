import express from "express";
import {
  createComplaint,
  getAllComplaints,
  getUserComplaints,
  updateComplaintStatus,
  deleteComplaint,
} from "../controllers/complaintController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../Middleware/authMiddleware.js";
import { isComplaintOwnerOrAdmin } from "../Middleware/ownership.js";

const router = express.Router();

/* 🧾 شكاوى */
router.post("/", protect, authorizeRoles("tenant"), createComplaint); // فقط التيننت

router.get("/", protect, authorizeRoles("admin"), getAllComplaints);

router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getUserComplaints
);

router.put(
  "/:id/status",
  protect,
  authorizeRoles("admin"),
  updateComplaintStatus
);

router.delete("/:id", protect, isComplaintOwnerOrAdmin, deleteComplaint);

export default router;
