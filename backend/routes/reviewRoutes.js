// routes/reviewRoutes.js
import express from "express";
import {
  addReview,
  getAllReviews,
  getReviewsByProperty,
  updateReview,
  deleteReview,
} from "../controllers/reviewController.js";

import { protect, authorizeRoles } from "../Middleware/authMiddleware.js";

const router = express.Router();

// ➕ إضافة تقييم (Tenant فقط)
router.post("/", protect, authorizeRoles("tenant"), addReview);

// 📋 عرض كل التقييمات (Public)
router.get("/", getAllReviews);

// 🏠 عرض تقييمات عقار معين
router.get("/property/:propertyId", getReviewsByProperty);

// ✏️ تعديل تقييم (صاحب التقييم أو أدمن)
router.put("/:id", protect, updateReview);

// ❌ حذف تقييم (صاحب التقييم أو أدمن)
router.delete("/:id", protect, deleteReview);

export default router;
