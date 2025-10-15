import express from "express";
import {
  addPayment,
  getAllPayments,
  getPaymentsByContract,
  getPaymentsByUser,
  updatePayment,
  deletePayment,
} from "../controllers/paymentController.js";

import {
  protect,
  authorizeRoles,
  permitSelfOrAdmin,
} from "../Middleware/authMiddleware.js";
import { isPaymentRelatedPartyOrAdmin } from "../Middleware/ownership.js";

const router = express.Router();

/* 💳 Payments */

/* 🔐 عرض كل الدفعات (Admin فقط) */
router.get("/", protect, authorizeRoles("admin"), getAllPayments);

/* 🧾 عرض دفعات عقد معيّن (طرفي العقد أو أدمن فقط) */
router.get(
  "/contract/:contractId",
  protect,
  isPaymentRelatedPartyOrAdmin,
  getPaymentsByContract
);

/* 👤 عرض دفعات مستخدم معيّن (نفس المستخدم أو أدمن) */
router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getPaymentsByUser
);

/* ➕ إنشاء دفعة جديدة (المالك أو الأدمن فقط) */
router.post("/", protect, authorizeRoles("landlord", "admin"), addPayment);

/* ✏️ تعديل دفعة (المالك أو الأدمن فقط) */
router.put(
  "/:id",
  protect,
  authorizeRoles("landlord", "admin"),
  isPaymentRelatedPartyOrAdmin,
  updatePayment
);

/* 🗑️ حذف دفعة (الأدمن فقط) */
router.delete("/:id", protect, authorizeRoles("admin"), deletePayment);

export default router;
