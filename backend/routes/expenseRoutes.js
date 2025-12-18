import express from "express";
import {
  addExpense,
  getAllExpenses,
  getExpenseById,
  updateExpense,
  deleteExpense,
  getExpenseStats,
} from "../controllers/expenseController.js";

import {
  protect,
  authorizeRoles,
} from "../Middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة مصروف (مالك أو أدمن)
router.post("/", authorizeRoles("landlord", "admin"), addExpense);

// 2. جلب جميع المصروفات
router.get("/", getAllExpenses);

// 3. إحصائيات المصروفات
router.get("/stats", getExpenseStats);

// 4. جلب مصروف محدد
router.get("/:id", getExpenseById);

// 5. تحديث مصروف (مالك أو أدمن)
router.put("/:id", authorizeRoles("landlord", "admin"), updateExpense);

// 6. حذف مصروف (مالك أو أدمن)
router.delete("/:id", authorizeRoles("landlord", "admin"), deleteExpense);

export default router;

