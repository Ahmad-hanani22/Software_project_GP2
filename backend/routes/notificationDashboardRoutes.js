import express from "express";
import { protect } from "../Middleware/authMiddleware.js";
import {
  getNotificationDashboard,
  markAllAsRead,
} from "../controllers/notificationDashboardController.js";

const router = express.Router();

/* 🧭 Dashboard routes */
router.get("/", protect, getNotificationDashboard);
router.put("/read-all", protect, markAllAsRead);

export default router;
