import express from "express";
import { protect } from "../Middleware/authMiddleware.js";

const router = express.Router();

// 📌 هذا الراوت محمي (Protected)
router.get("/check", protect, (req, res) => {
  res.json({
    message: "✅ Token verified successfully!",
    user: req.user, // هذا فيه بيانات المستخدم من التوكن
  });
});

export default router;
