// routes/userRoutes.js
import express from "express";
// 👇 تأكد من استيراد الدالة الجديدة updateUserProfile
import { protect } from "../Middleware/authMiddleware.js"; // تأكد من استيراد protect
import { registerUser, loginUser, getMe, updateUserProfile, getUsersForChat } from "../controllers/userController.js";

const router = express.Router();

router.post("/register", registerUser);
router.post("/login", loginUser);
router.get("/me", protect, getMe);

// 👇👇 أضف هذا السطر الجديد 👇👇
router.put("/profile", protect, updateUserProfile);
router.get("/chat-list", protect, getUsersForChat);

export default router;