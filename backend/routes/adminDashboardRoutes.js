import express from "express";
import { getDashboardStats } from "../controllers/adminDashboardController.js";
// ✅ لاحقاً ممكن تضيف middleware للتحقق من صلاحيات الأدمن

const router = express.Router();

// GET /api/admin/dashboard
router.get("/dashboard", getDashboardStats);

export default router;
