import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import { sendNotificationToUser } from "../utils/sendNotification.js";

const router = express.Router();

// ✅ Route فحص JWT Token
router.get("/check", protect, (req, res) => {
  res.json({
    message: "✅ Token verified successfully!",
    user: req.user,
  });
});

// 🔔 Route اختبار Push Notification حقيقي (بـ userId من URL)
router.get("/test-push/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    await sendNotificationToUser({
      userId,
      title: "🧪 Test Notification - SHAQATI",
      message: "إذا وصلك هذا الإشعار في شريط النظام، فـ FCM شغال 100% 🎉",
      type: "system", // ✅ بدل test
    });

    res.json({
      success: true,
      message: "🔔 Test push sent successfully",
    });
  } catch (err) {
    console.error("❌ Test push error:", err);
    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

// 🔐 Route اختبار Push للمستخدم الحالي (JWT)
router.get("/test-push-me", protect, async (req, res) => {
  try {
    const userId = req.user._id;

    await sendNotificationToUser({
      userId,
      title: "🧪 Test Notification - SHAQATI",
      message: "إذا وصلك هذا الإشعار في شريط النظام، فـ FCM شغال 100% 🎉",
      type: "system", // ✅ بدل test
    });

    res.json({
      success: true,
      message: "🔔 Test push sent successfully (current user)",
    });
  } catch (err) {
    console.error("❌ Test push (me) error:", err);
    res.status(500).json({
      success: false,
      error: err.message,
    });
  }
});

export default router;
