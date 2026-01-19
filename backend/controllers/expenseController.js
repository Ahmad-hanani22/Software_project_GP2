import Expense from "../models/Expense.js";
import Property from "../models/Property.js";
import Unit from "../models/Unit.js";

// 1. إضافة مصروف
export const addExpense = async (req, res) => {
  try {
    const { propertyId, unitId } = req.body;

    // التحقق من الصلاحيات
    if (propertyId) {
      const property = await Property.findById(propertyId);
      if (
        !property ||
        (String(property.ownerId) !== String(req.user._id) &&
          req.user.role !== "admin")
      ) {
        return res.status(403).json({
          message: "You are not authorized to add expenses for this property",
        });
      }
    }

    if (unitId) {
      const unit = await Unit.findById(unitId);
      if (unit) {
        const property = await Property.findById(unit.propertyId);
        if (
          String(property.ownerId) !== String(req.user._id) &&
          req.user.role !== "admin"
        ) {
          return res.status(403).json({
            message: "You are not authorized to add expenses for this unit",
          });
        }
      }
    }

    const expense = new Expense({
      ...req.body,
      paidBy: req.user._id,
    });
    await expense.save();

    res.status(201).json({
      message: "✅ Expense added successfully",
      expense,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error adding expense",
      error: error.message,
    });
  }
};

// 2. جلب جميع المصروفات
export const getAllExpenses = async (req, res) => {
  try {
    const { propertyId, unitId, type, startDate, endDate } = req.query;
    const filter = {};

    // إذا لم يكن أدمن، عرض فقط مصروفات العقارات الخاصة به أو المصروفات التي قام بإنشائها
    if (req.user.role !== "admin") {
      const userProperties = await Property.find({ ownerId: req.user._id });
      const propertyIds = userProperties.map((p) => p._id);
      
      // بناء $or condition ليشمل:
      // 1. المصروفات المرتبطة بعقارات المستخدم (إذا كان يملك عقارات)
      // 2. المصروفات التي قام المستخدم بإنشائها (paidBy) حتى لو لم تكن مرتبطة بعقار
      const orConditions = [];
      
      // إضافة شرط العقارات فقط إذا كان المستخدم يملك عقارات
      if (propertyIds.length > 0) {
        orConditions.push({ propertyId: { $in: propertyIds } });
      }
      
      // إضافة المصروفات التي قام المستخدم بإنشائها بدون propertyId
      orConditions.push({ paidBy: req.user._id, propertyId: null });
      orConditions.push({ paidBy: req.user._id, propertyId: { $exists: false } });
      
      // بناء الفلتر الأساسي مع $or
      const baseFilter = { $or: orConditions };
      
      // إضافة الفلاتر الأخرى باستخدام $and
      const andConditions = [baseFilter];
      if (unitId) andConditions.push({ unitId: unitId });
      if (type) andConditions.push({ type: type });
      if (startDate || endDate) {
        const dateFilter = {};
        if (startDate) dateFilter.$gte = new Date(startDate);
        if (endDate) dateFilter.$lte = new Date(endDate);
        andConditions.push({ date: dateFilter });
      }
      
      // استخدام $and إذا كان هناك فلاتر إضافية، وإلا استخدم $or مباشرة
      if (andConditions.length > 1) {
        filter.$and = andConditions;
      } else {
        Object.assign(filter, baseFilter);
      }
    } else {
      // إذا كان أدمن، استخدم الفلاتر العادية
      if (propertyId) filter.propertyId = propertyId;
      if (unitId) filter.unitId = unitId;
      if (type) filter.type = type;
      if (startDate || endDate) {
        filter.date = {};
        if (startDate) filter.date.$gte = new Date(startDate);
        if (endDate) filter.date.$lte = new Date(endDate);
      }
    }

    const expenses = await Expense.find(filter)
      .populate("propertyId", "title address")
      .populate("unitId", "unitNumber")
      .populate("paidBy", "name email")
      .populate("contractId", "tenantId landlordId")
      .sort({ date: -1 });

    // حساب الإجمالي
    const total = expenses.reduce((sum, exp) => sum + (exp.amount || 0), 0);

    res.status(200).json({
      expenses,
      total,
      count: expenses.length,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching expenses",
      error: error.message,
    });
  }
};

// 3. جلب مصروف محدد
export const getExpenseById = async (req, res) => {
  try {
    const expense = await Expense.findById(req.params.id)
      .populate("propertyId")
      .populate("unitId")
      .populate("paidBy", "name email")
      .populate("contractId");

    if (!expense) {
      return res.status(404).json({ message: "Expense not found" });
    }

    res.status(200).json(expense);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching expense",
      error: error.message,
    });
  }
};

// 4. تحديث مصروف
export const updateExpense = async (req, res) => {
  try {
    const expense = await Expense.findById(req.params.id);
    if (!expense) {
      return res.status(404).json({ message: "Expense not found" });
    }

    // التحقق من الصلاحيات
    if (expense.propertyId) {
      const property = await Property.findById(expense.propertyId);
      if (
        String(property.ownerId) !== String(req.user._id) &&
        req.user.role !== "admin"
      ) {
        return res.status(403).json({
          message: "You are not authorized to update this expense",
        });
      }
    }

    const updatedExpense = await Expense.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    res.status(200).json({
      message: "✅ Expense updated successfully",
      expense: updatedExpense,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating expense",
      error: error.message,
    });
  }
};

// 5. حذف مصروف
export const deleteExpense = async (req, res) => {
  try {
    const expense = await Expense.findById(req.params.id);
    if (!expense) {
      return res.status(404).json({ message: "Expense not found" });
    }

    // التحقق من الصلاحيات
    if (expense.propertyId) {
      const property = await Property.findById(expense.propertyId);
      if (
        String(property.ownerId) !== String(req.user._id) &&
        req.user.role !== "admin"
      ) {
        return res.status(403).json({
          message: "You are not authorized to delete this expense",
        });
      }
    }

    await Expense.findByIdAndDelete(req.params.id);

    res.status(200).json({ message: "🗑️ Expense deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting expense",
      error: error.message,
    });
  }
};

// 6. إحصائيات المصروفات
export const getExpenseStats = async (req, res) => {
  try {
    const { propertyId, unitId, startDate, endDate } = req.query;
    const filter = {};

    if (propertyId) filter.propertyId = propertyId;
    if (unitId) filter.unitId = unitId;

    if (startDate || endDate) {
      filter.date = {};
      if (startDate) filter.date.$gte = new Date(startDate);
      if (endDate) filter.date.$lte = new Date(endDate);
    }

    // إذا لم يكن أدمن، عرض فقط مصروفات العقارات الخاصة به
    if (req.user.role !== "admin") {
      const userProperties = await Property.find({ ownerId: req.user._id });
      const propertyIds = userProperties.map((p) => p._id);
      filter.propertyId = { $in: propertyIds };
    }

    const stats = await Expense.aggregate([
      { $match: filter },
      {
        $group: {
          _id: "$type",
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);

    const overallTotal = await Expense.aggregate([
      { $match: filter },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]);

    res.status(200).json({
      byType: stats,
      overallTotal: overallTotal[0]?.total || 0,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching expense stats",
      error: error.message,
    });
  }
};

