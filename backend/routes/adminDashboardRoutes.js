import express from "express";
import { getDashboardStats } from "../controllers/adminDashboardController.js";
import { protect, authorizeRoles } from "../Middleware/authMiddleware.js";

const router = express.Router();

// ✅ http://localhost:5000/api/admin/dashboard
router.get("/", protect, authorizeRoles("admin"), getDashboardStats);

export default router;
