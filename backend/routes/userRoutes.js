import express from "express";
import { protect } from "../Middleware/authMiddleware.js";

import { 
  registerUser,
  loginUser,
  getMe,
  updateUserProfile,
  getUsersForChat
} from "../controllers/userController.js";

const router = express.Router();

// Auth
router.post("/register", registerUser);
router.post("/login", loginUser);
router.get("/me", protect, getMe);

// Update profile
router.put("/profile", protect, updateUserProfile);

// Chat list
router.get("/chat-list", protect, getUsersForChat);

export default router;
