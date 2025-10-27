import express from "express";
import { protect, authorizeRoles } from "../Middleware/authMiddleware.js";
import {
  getReviews,
  createReview,
  updateReview,
  deleteReview
} from "../controllers/reviewController.js";

const router = express.Router();

router.post("/", protect, authorizeRoles("tenant"), createReview);
router.get("/", protect, authorizeRoles("admin"), getReviews);

//router.get("/:id", protect, getReviewById);
router.delete("/:id", protect, authorizeRoles("admin"), deleteReview);

export default router;
