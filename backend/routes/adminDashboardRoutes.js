import express from "express";
import { getDashboardStats } from "../controllers/adminDashboardController.js";
import { protect, authorizeRoles } from "../Middleware/authMiddleware.js";

const router = express.Router();

// 🧭 لوحة تحكم الأدمن
router.get("/", protect, authorizeRoles("admin"), getDashboardStats);

export default router;
