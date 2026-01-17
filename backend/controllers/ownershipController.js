import Ownership from "../models/Ownership.js";
import Property from "../models/Property.js";
import User from "../models/User.js";

// 1. إضافة ملكية (نسبة في عقار)
export const addOwnership = async (req, res) => {
  try {
    const { propertyId, ownerId, percentage, isPrimary } = req.body;

    // ✅ التحقق من البيانات المطلوبة
    if (!propertyId || !ownerId || percentage === undefined || percentage === null) {
      return res.status(400).json({
        message: "Property ID, Owner ID, and Percentage are required",
      });
    }

    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // ✅ التحقق من أن ownerId موجود كـ User
    const ownerUser = await User.findById(ownerId);
    if (!ownerUser) {
      return res.status(404).json({ message: "Owner user not found" });
    }

    // ✅ التحقق من الصلاحيات (مالك العقار أو أدمن)
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to add ownership for this property",
      });
    }

    // ✅ التحقق من أن النسبة صحيحة
    if (percentage < 0 || percentage > 100) {
      return res.status(400).json({
        message: "Ownership percentage must be between 0 and 100",
      });
    }

    const ownership = new Ownership({
      propertyId,
      ownerId,
      percentage: Number(percentage),
      isPrimary: isPrimary || false,
    });

    await ownership.save();

    res.status(201).json({
      message: "✅ Ownership added successfully",
      ownership,
    });
  } catch (error) {
    if (error.message.includes("percentage")) {
      return res.status(400).json({ message: error.message });
    }
    if (error.code === 11000) {
      return res.status(400).json({
        message: "This owner already has ownership in this property",
      });
    }
    res.status(500).json({
      message: "❌ Error adding ownership",
      error: error.message,
    });
  }
};

// 2. جلب ملكيات عقار معين
export const getPropertyOwnership = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const ownerships = await Ownership.find({ propertyId })
      .populate("ownerId", "name email")
      .populate("propertyId", "title");

    res.status(200).json(ownerships);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property ownership",
      error: error.message,
    });
  }
};

// 3. جلب عقارات مالك معين
export const getOwnerProperties = async (req, res) => {
  try {
    const { ownerId } = req.params;

    const ownerships = await Ownership.find({ ownerId })
      .populate("propertyId", "title address price")
      .populate("ownerId", "name email");

    res.status(200).json(ownerships);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching owner properties",
      error: error.message,
    });
  }
};

// 4. تحديث ملكية
export const updateOwnership = async (req, res) => {
  try {
    const ownership = await Ownership.findById(req.params.id);
    if (!ownership) {
      return res.status(404).json({ message: "Ownership not found" });
    }

    const property = await Property.findById(ownership.propertyId);
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to update this ownership",
      });
    }

    const updatedOwnership = await Ownership.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    )
      .populate("ownerId", "name email")
      .populate("propertyId", "title");

    res.status(200).json({
      message: "✅ Ownership updated successfully",
      ownership: updatedOwnership,
    });
  } catch (error) {
    if (error.message.includes("percentage")) {
      return res.status(400).json({ message: error.message });
    }
    res.status(500).json({
      message: "❌ Error updating ownership",
      error: error.message,
    });
  }
};

// 5. حذف ملكية
export const deleteOwnership = async (req, res) => {
  try {
    const ownership = await Ownership.findById(req.params.id);
    if (!ownership) {
      return res.status(404).json({ message: "Ownership not found" });
    }

    const property = await Property.findById(ownership.propertyId);
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to delete this ownership",
      });
    }

    await Ownership.findByIdAndDelete(req.params.id);

    res.status(200).json({ message: "🗑️ Ownership deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting ownership",
      error: error.message,
    });
  }
};

