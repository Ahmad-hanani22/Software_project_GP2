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
} from "../middleware/authMiddleware.js";
import { isComplaintOwnerOrAdmin } from "../middleware/ownership.js";
import upload from "../middleware/uploadMiddleware.js";
import { uploadToCloudinary } from "../middleware/uploadMiddleware.js";

const router = express.Router();

/* 🧾 شكاوى */
// إنشاء شكوى (مع بيانات التصنيف والمرفقات كـ JSON)
router.post("/", protect, authorizeRoles("tenant"), createComplaint);

// رفع مرفقات الشكوى (صور / ملفات) وإرجاع روابطها (يمكن استدعاؤها قبل createComplaint)
router.post(
  "/upload-attachment",
  protect,
  authorizeRoles("tenant"),
  upload.single("file"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: "No file uploaded" });
      }
      const result = await uploadToCloudinary(req.file.buffer);
      return res.status(200).json({
        message: "Attachment uploaded successfully",
        url: result.secure_url,
        name: req.file.originalname,
      });
    } catch (error) {
      return res.status(500).json({
        message: "❌ Error uploading attachment",
        error: error.message,
      });
    }
  }
);

router.get("/", protect, authorizeRoles("admin"), getAllComplaints);

router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getUserComplaints
);

// تحديث حالة الشكوى + قرار الأدمن النهائي
router.put(
  "/:id/status",
  protect,
  authorizeRoles("admin"),
  updateComplaintStatus
);

router.delete("/:id", protect, isComplaintOwnerOrAdmin, deleteComplaint);

export default router;
