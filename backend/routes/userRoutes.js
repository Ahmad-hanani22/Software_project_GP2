import express from "express";
import {
  registerUser,
  loginUser,
  getMe,
  updateUserProfile,
  getUsersForChat,
  verifyUserEmail,
  getAdminUsers,
} from "../controllers/userController.js";
import { protect } from "../Middleware/authMiddleware.js";

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

export default router;
