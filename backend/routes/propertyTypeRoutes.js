// routes/propertyTypeRoutes.js
import express from "express";
import {
  getAllPropertyTypes,
  getPropertyTypeById,
  createPropertyType,
  updatePropertyType,
  deletePropertyType,
  togglePropertyTypeStatus,
  getPropertyTypeStats,
} from "../controllers/propertyTypeController.js";
import { body } from "express-validator";
import { protect, admin } from "../Middleware/authMiddleware.js";

const router = express.Router();

// Validation rules
const createPropertyTypeValidation = [
  body("name")
    .trim()
    .notEmpty()
    .withMessage("Property type name is required")
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

const updatePropertyTypeValidation = [
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
// 📋 Public: الحصول على جميع أنواع العقارات (النشطة فقط)
router.get("/", getAllPropertyTypes);

// 📊 Public: إحصائيات أنواع العقارات
router.get("/stats", getPropertyTypeStats);

// 📋 Public: الحصول على نوع عقار واحد
router.get("/:id", getPropertyTypeById);

// ➕ Admin: إنشاء نوع عقار جديد
router.post("/", protect, admin, createPropertyTypeValidation, createPropertyType);

// ✏️ Admin: تحديث نوع عقار
router.put("/:id", protect, admin, updatePropertyTypeValidation, updatePropertyType);

// 🗑️ Admin: حذف نوع عقار
router.delete("/:id", protect, admin, deletePropertyType);

// 🔄 Admin: تفعيل/تعطيل نوع عقار
router.patch("/:id/toggle", protect, admin, togglePropertyTypeStatus);

export default router;

