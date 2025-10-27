// routes/adminSettingsRoutes.js
import express from "express";
import { body } from "express-validator";
import {
  getSystemSettings,
  updateSystemSetting,
} from "../controllers/adminSettingsController.js";
import { protect, authorizeRoles } from "../Middleware/authMiddleware.js"; 

const router = express.Router();

router.get("/", protect, authorizeRoles("admin"), getSystemSettings);

router.put(
  "/:key",
  protect,
  authorizeRoles("admin"),
  [body("value").exists().withMessage("Setting value is required.")],
  updateSystemSetting
);

export default router;
