// routes/amenityRoutes.js
import express from "express";
import {
  getAllAmenities,
  getAmenityById,
  createAmenity,
  updateAmenity,
  deleteAmenity,
  toggleAmenityStatus,
  getAmenityStats,
} from "../controllers/amenityController.js";
import { body } from "express-validator";
import { protect, admin, authorizeRoles } from "../middleware/authMiddleware.js";

const router = express.Router();

// Validation rules
const createAmenityValidation = [
  body("name")
    .trim()
    .notEmpty()
    .withMessage("Amenity name is required")
    .isLength({ min: 2, max: 50 })
    .withMessage("Name must be between 2 and 50 characters"),
  body("displayName")
    .trim()
    .notEmpty()
    .withMessage("Display name is required")
    .isLength({ min: 2, max: 50 })
    .withMessage("Display name must be between 2 and 50 characters"),
  body("icon").optional().trim(),
  body("description").optional().trim(),
  body("order").optional().isInt({ min: 0 }).withMessage("Order must be a non-negative integer"),
];

const updateAmenityValidation = [
  body("name")
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage("Name must be between 2 and 50 characters"),
  body("displayName")
    .optional()
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage("Display name must be between 2 and 50 characters"),
  body("icon").optional().trim(),
  body("description").optional().trim(),
  body("order").optional().isInt({ min: 0 }).withMessage("Order must be a non-negative integer"),
  body("isActive").optional().isBoolean().withMessage("isActive must be a boolean"),
];

// Routes
// 📋 Public: الحصول على جميع المميزات (النشطة فقط)
router.get("/", getAllAmenities);

// 📊 Public: إحصائيات المميزات
router.get("/stats", getAmenityStats);

// 📋 Public: الحصول على مميزة واحدة
router.get("/:id", getAmenityById);

// ➕ Admin/Landlord: إنشاء مميزة جديدة
router.post("/", protect, authorizeRoles("admin", "landlord"), createAmenityValidation, createAmenity);

// ✏️ Admin/Landlord: تحديث مميزة
router.put("/:id", protect, authorizeRoles("admin", "landlord"), updateAmenityValidation, updateAmenity);

// 🗑️ Admin: حذف مميزة (Admin only)
router.delete("/:id", protect, admin, deleteAmenity);

// 🔄 Admin/Landlord: تفعيل/تعطيل مميزة
router.patch("/:id/toggle", protect, authorizeRoles("admin", "landlord"), toggleAmenityStatus);

export default router;
