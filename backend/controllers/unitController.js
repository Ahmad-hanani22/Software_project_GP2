import Unit from "../models/Unit.js";
import Property from "../models/Property.js";
import Contract from "../models/Contract.js";
import OccupancyHistory from "../models/OccupancyHistory.js";
import { sendNotification } from "../utils/sendNotification.js";

// 1. إنشاء وحدة جديدة
export const addUnit = async (req, res) => {
  try {
    const { propertyId } = req.body;

    // التحقق من وجود العقار
    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // التحقق من أن المستخدم هو مالك العقار أو أدمن
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to add units to this property",
      });
    }

    const unit = new Unit(req.body);
    await unit.save();

    res.status(201).json({
      message: "✅ Unit created successfully",
      unit,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        message: "Unit number already exists for this property",
      });
    }
    res.status(500).json({
      message: "❌ Error creating unit",
      error: error.message,
    });
  }
};

// 2. جلب جميع الوحدات
export const getAllUnits = async (req, res) => {
  try {
    const { propertyId, status } = req.query;
    const filter = {};

    if (propertyId) filter.propertyId = propertyId;
    if (status) filter.status = status;

    const units = await Unit.find(filter)
      .populate("propertyId", "title address")
      .sort({ createdAt: -1 });

    res.status(200).json(units);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching units",
      error: error.message,
    });
  }
};

// 3. جلب وحدة محددة
export const getUnitById = async (req, res) => {
  try {
    const unit = await Unit.findById(req.params.id)
      .populate("propertyId", "title address ownerId")
      .populate({
        path: "propertyId",
        populate: { path: "ownerId", select: "name email" },
      });

    if (!unit) {
      return res.status(404).json({ message: "Unit not found" });
    }

    // جلب العقد النشط للوحدة
    const activeContract = await Contract.findOne({
      unitId: unit._id,
      status: "active",
    })
      .populate("tenantId", "name email phone")
      .populate("landlordId", "name email phone");

    // جلب آخر سجل إشغال
    const lastOccupancy = await OccupancyHistory.findOne({
      unitId: unit._id,
    })
      .sort({ from: -1 })
      .populate("tenantId", "name email");

    res.status(200).json({
      unit,
      activeContract,
      lastOccupancy,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching unit",
      error: error.message,
    });
  }
};

// 4. جلب وحدات عقار معين
export const getUnitsByProperty = async (req, res) => {
  try {
    const { propertyId } = req.params;
    const units = await Unit.find({ propertyId })
      .populate("propertyId", "title")
      .sort({ floor: 1, unitNumber: 1 });

    res.status(200).json(units);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property units",
      error: error.message,
    });
  }
};

// 5. تحديث وحدة
export const updateUnit = async (req, res) => {
  try {
    const unit = await Unit.findById(req.params.id);
    if (!unit) {
      return res.status(404).json({ message: "Unit not found" });
    }

    // التحقق من الصلاحيات
    const property = await Property.findById(unit.propertyId);
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to update this unit",
      });
    }

    // منع تغيير حالة الوحدة إذا كانت مشغولة بعقد نشط
    if (req.body.status === "vacant") {
      const activeContract = await Contract.findOne({
        unitId: unit._id,
        status: "active",
      });
      if (activeContract) {
        return res.status(400).json({
          message:
            "Cannot set unit to vacant while there is an active contract",
        });
      }
    }

    const updatedUnit = await Unit.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    res.status(200).json({
      message: "✅ Unit updated successfully",
      unit: updatedUnit,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating unit",
      error: error.message,
    });
  }
};

// 6. حذف وحدة
export const deleteUnit = async (req, res) => {
  try {
    const unit = await Unit.findById(req.params.id);
    if (!unit) {
      return res.status(404).json({ message: "Unit not found" });
    }

    // التحقق من الصلاحيات
    const property = await Property.findById(unit.propertyId);
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to delete this unit",
      });
    }

    // التحقق من عدم وجود عقود نشطة
    const activeContract = await Contract.findOne({
      unitId: unit._id,
      status: { $in: ["active", "pending"] },
    });
    if (activeContract) {
      return res.status(400).json({
        message: "Cannot delete unit with active or pending contracts",
      });
    }

    await Unit.findByIdAndDelete(req.params.id);

    res.status(200).json({ message: "🗑️ Unit deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting unit",
      error: error.message,
    });
  }
};

// 7. جلب إحصائيات الوحدة
export const getUnitStats = async (req, res) => {
  try {
    const { id } = req.params;

    const unit = await Unit.findById(id);
    if (!unit) {
      return res.status(404).json({ message: "Unit not found" });
    }

    // عدد العقود
    const contractsCount = await Contract.countDocuments({
      unitId: id,
    });

    // آخر عقد نشط
    const activeContract = await Contract.findOne({
      unitId: id,
      status: "active",
    });

    // سجلات الإشغال
    const occupancyCount = await OccupancyHistory.countDocuments({
      unitId: id,
    });

    res.status(200).json({
      unit,
      stats: {
        contractsCount,
        occupancyCount,
        hasActiveContract: !!activeContract,
      },
      activeContract,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching unit stats",
      error: error.message,
    });
  }
};

