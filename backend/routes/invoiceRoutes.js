import express from "express";
import {
  createInvoice,
  getAllInvoices,
  getInvoiceById,
  updateInvoice,
} from "../controllers/invoiceController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إنشاء فاتورة (مالك أو أدمن)
router.post("/", authorizeRoles("landlord", "admin"), createInvoice);

// 2. جلب جميع الفواتير
router.get("/", getAllInvoices);

// 3. جلب فاتورة محددة
router.get("/:id", getInvoiceById);

// 4. تحديث فاتورة (مالك أو أدمن)
router.put("/:id", authorizeRoles("landlord", "admin"), updateInvoice);

export default router;

