import OccupancyHistory from "../models/OccupancyHistory.js";
import Unit from "../models/Unit.js";
import Contract from "../models/Contract.js";

// 1. إضافة سجل إشغال (يتم إنشاؤه تلقائياً عند تفعيل عقد)
export const addOccupancyHistory = async (req, res) => {
  try {
    const { unitId, tenantId, contractId, from, to } = req.body;

    const unit = await Unit.findById(unitId);
    if (!unit) {
      return res.status(404).json({ message: "Unit not found" });
    }

    const occupancy = new OccupancyHistory({
      unitId,
      tenantId,
      contractId,
      from: from || new Date(),
      to: to || null,
      notes: req.body.notes,
    });

    await occupancy.save();

    res.status(201).json({
      message: "✅ Occupancy history added successfully",
      occupancy,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error adding occupancy history",
      error: error.message,
    });
  }
};

// 2. جلب سجل إشغال وحدة معينة
export const getOccupancyByUnit = async (req, res) => {
  try {
    const { unitId } = req.params;
    const occupancies = await OccupancyHistory.find({ unitId })
      .populate("tenantId", "name email phone")
      .populate("contractId", "startDate endDate rentAmount")
      .sort({ from: -1 });

    res.status(200).json(occupancies);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching occupancy history",
      error: error.message,
    });
  }
};

// 3. جلب سجل إشغال مستأجر معين
export const getOccupancyByTenant = async (req, res) => {
  try {
    const { tenantId } = req.params;

    // التحقق من الصلاحيات
    if (
      String(tenantId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to view this occupancy history",
      });
    }

    const occupancies = await OccupancyHistory.find({ tenantId })
      .populate("unitId", "unitNumber floor rentPrice")
      .populate({
        path: "unitId",
        populate: { path: "propertyId", select: "title address" },
      })
      .populate("contractId", "startDate endDate")
      .sort({ from: -1 });

    res.status(200).json(occupancies);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching occupancy history",
      error: error.message,
    });
  }
};

// 4. تحديث سجل إشغال (مثلاً عند انتهاء العقد)
export const updateOccupancyHistory = async (req, res) => {
  try {
    const occupancy = await OccupancyHistory.findById(req.params.id);
    if (!occupancy) {
      return res.status(404).json({ message: "Occupancy history not found" });
    }

    // إذا تم تعيين تاريخ انتهاء، تحديث السجل
    if (req.body.to) {
      occupancy.to = new Date(req.body.to);
    }

    if (req.body.notes) {
      occupancy.notes = req.body.notes;
    }

    await occupancy.save();

    res.status(200).json({
      message: "✅ Occupancy history updated successfully",
      occupancy,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating occupancy history",
      error: error.message,
    });
  }
};

// 5. جلب جميع سجلات الإشغال (للأدمن)
export const getAllOccupancyHistory = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res.status(403).json({
        message: "Only admin can view all occupancy history",
      });
    }

    const { unitId, tenantId } = req.query;
    const filter = {};

    if (unitId) filter.unitId = unitId;
    if (tenantId) filter.tenantId = tenantId;

    const occupancies = await OccupancyHistory.find(filter)
      .populate("unitId", "unitNumber floor")
      .populate({
        path: "unitId",
        populate: { path: "propertyId", select: "title address" },
      })
      .populate("tenantId", "name email")
      .populate("contractId", "startDate endDate")
      .sort({ from: -1 });

    res.status(200).json(occupancies);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching occupancy history",
      error: error.message,
    });
  }
};

