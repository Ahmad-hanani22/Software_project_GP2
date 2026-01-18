// routes/adminRoutes.js
import express from "express";
import {
  createAdmin,
  getAllAdmins,
  updateAdmin,
  deleteAdmin,
  checkPermission,
  getAllUsers,
  createUserByAdmin,
  updateUserByAdmin,
  deleteUserByAdmin,
} from "../controllers/adminController.js";
import { protect, authorizeRoles } from "../middleware/authMiddleware.js";
import { getDashboardStats } from "../controllers/adminDashboardController.js";

const router = express.Router();

router.get("/dashboard", protect, authorizeRoles("admin"), getDashboardStats);
// أدمن (roles)
router.post("/", protect, authorizeRoles("admin"), createAdmin);
router.get("/", protect, authorizeRoles("admin"), getAllAdmins);
router.put("/:id", protect, authorizeRoles("admin"), updateAdmin);
router.delete("/:id", protect, authorizeRoles("admin"), deleteAdmin);
router.post(
  "/check-permission",
  protect,
  authorizeRoles("admin"),
  checkPermission
);

// 👇 إدارة المستخدمين (للوحة الأدمن)
router.get("/users", protect, authorizeRoles("admin"), getAllUsers);
router.post("/users", protect, authorizeRoles("admin"), createUserByAdmin);
router.put("/users/:id", protect, authorizeRoles("admin"), updateUserByAdmin);
router.delete(
  "/users/:id",
  protect,
  authorizeRoles("admin"),
  deleteUserByAdmin
);

export default router;
