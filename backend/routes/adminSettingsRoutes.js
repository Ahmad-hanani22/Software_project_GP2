// routes/adminSettingsRoutes.js
import express from "express";
import { body } from "express-validator";
import {
  getSystemSettings,
  updateSystemSetting,
} from "../controllers/adminSettingsController.js"; // تأكد من المسار الصحيح
import { protect, authorizeRoles } from "../Middleware/authMiddleware.js"; // تأكد من المسار الصحيح

const router = express.Router();

// ✅ جلب جميع إعدادات النظام (للمسؤولين فقط)
router.get("/", protect, authorizeRoles("admin"), getSystemSettings);

// ✅ تحديث إعداد نظام واحد بواسطة المفتاح (للمسؤولين فقط)
router.put(
  "/:key",
  protect,
  authorizeRoles("admin"),
  [body("value").exists().withMessage("Setting value is required.")],
  updateSystemSetting
);

export default router;
