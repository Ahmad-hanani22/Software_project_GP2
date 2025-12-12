import express from "express";
// 👇 تأكد من استيراد verifyUserEmail
import { registerUser, loginUser, getMe, updateUserProfile, getUsersForChat, verifyUserEmail } from "../controllers/userController.js";
import { protect } from "../Middleware/authMiddleware.js";

const router = express.Router();

router.post("/register", registerUser);
router.post("/login", loginUser);
router.get("/me", protect, getMe);
router.put("/profile", protect, updateUserProfile);
router.get("/chat-list", protect, getUsersForChat);

// 👇👇 الرابط الجديد للتفعيل (بدون protect لأنه يأتي من الإيميل)
router.get("/verify/:token", verifyUserEmail);

export default router;