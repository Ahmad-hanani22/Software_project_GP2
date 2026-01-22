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
} from "../middleware/authMiddleware.js";

const router = express.Router();

router.use(protect);

// 1. إضافة مصروف (مالك، أدمن، أو مستأجر)
router.post("/", addExpense);

// 2. جلب جميع المصروفات
router.get("/", getAllExpenses);

// 3. إحصائيات المصروفات
router.get("/stats", getExpenseStats);

// 4. جلب مصروف محدد
router.get("/:id", getExpenseById);

// 5. تحديث مصروف (مالك، أدمن، أو مستأجر - لمصروفاته فقط)
router.put("/:id", updateExpense);

// 6. حذف مصروف (مالك، أدمن، أو مستأجر - لمصروفاته فقط)
router.delete("/:id", deleteExpense);

export default router;

