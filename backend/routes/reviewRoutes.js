// routes/reviewRoutes.js
import express from "express";
import { protect, authorizeRoles } from "../Middleware/authMiddleware.js";
import {
  getReviews,
  createReview,
  updateReview,
  deleteReview,
  getReviewsByProperty,
} from "../controllers/reviewController.js";

const router = express.Router();

router.get("/property/:propertyId", getReviewsByProperty);
router.post("/", protect, authorizeRoles("tenant"), createReview);
router.get("/", protect, authorizeRoles("admin"), getReviews);

router.put("/:id", protect, authorizeRoles("admin"), updateReview);

router.delete("/:id", protect, authorizeRoles("admin"), deleteReview);

export default router;