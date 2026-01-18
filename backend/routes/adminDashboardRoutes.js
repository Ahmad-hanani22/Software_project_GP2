import express from "express";
import { getDashboardStats } from "../controllers/adminDashboardController.js";
import { protect, authorizeRoles } from "../middleware/authMiddleware.js";

const router = express.Router();

// 👇 خلي المسار /dashboard
router.get("/dashboard", protect, authorizeRoles("admin"), getDashboardStats);

export default router;
