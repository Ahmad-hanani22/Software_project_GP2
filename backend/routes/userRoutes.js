import express from "express";
import {
  registerUser,
  loginUser,
  getMe,
  updateUserProfile,
  getUsersForChat,
  verifyUserEmail,
  getAdminUsers,
  registerFCMToken,
} from "../controllers/userController.js";
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

// Auth
router.post("/register", registerUser);
router.post("/login", loginUser);
router.get("/verify/:token", verifyUserEmail);

// User
router.get("/me", protect, getMe);
router.put("/profile", protect, updateUserProfile);
router.get("/chat-list", protect, getUsersForChat);
router.get("/admins", protect, getAdminUsers);

// 🔔 FCM Token Registration (يجب أن يكون قبل Routes العامة)
router.put("/:userId/fcm-token", protect, registerFCMToken);

export default router;
