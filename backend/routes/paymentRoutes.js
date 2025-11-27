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

router.get("/", protect, authorizeRoles("admin"), getAllPayments);

router.get(
  "/contract/:contractId",
  protect,
  isPaymentRelatedPartyOrAdmin,
  getPaymentsByContract
);

router.get(
  "/user/:userId",
  protect,
  permitSelfOrAdmin("userId"),
  getPaymentsByUser
);

router.post("/", protect, authorizeRoles("landlord", "admin","tenant"), addPayment);

router.put(
  "/:id",
  protect,
  authorizeRoles("landlord", "admin"),
  isPaymentRelatedPartyOrAdmin,
  updatePayment
);

router.delete("/:id", protect, authorizeRoles("admin"), deletePayment);

export default router;
