// routes/userRoutes.js
import express from "express";
// 👇 تأكد من استيراد الدالة الجديدة updateUserProfile
import { registerUser, loginUser, getMe, updateUserProfile } from "../controllers/userController.js";
import { protect } from "../Middleware/authMiddleware.js"; // تأكد من استيراد protect

const router = express.Router();

router.post("/register", registerUser);
router.post("/login", loginUser);
router.get("/me", protect, getMe);

// 👇👇 أضف هذا السطر الجديد 👇👇
router.put("/profile", protect, updateUserProfile);

export default router;