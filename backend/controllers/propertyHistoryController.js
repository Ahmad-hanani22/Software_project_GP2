import PropertyHistory from "../models/PropertyHistory.js";
import Property from "../models/Property.js";

// 1. إنشاء سجل تاريخ عقار (عادة يتم تلقائياً عند التعديل)
export const addPropertyHistory = async (req, res) => {
  try {
    const { propertyId, action, changes, description } = req.body;

    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    const history = new PropertyHistory({
      propertyId,
      action,
      performedBy: req.user._id,
      changes,
      description,
    });

    await history.save();

    res.status(201).json({
      message: "✅ Property history added successfully",
      history,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error adding property history",
      error: error.message,
    });
  }
};

// 2. جلب تاريخ عقار معين
export const getPropertyHistory = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const histories = await PropertyHistory.find({ propertyId })
      .populate("performedBy", "name email")
      .populate("propertyId", "title")
      .sort({ createdAt: -1 });

    res.status(200).json(histories);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property history",
      error: error.message,
    });
  }
};

// 3. جلب جميع سجلات التاريخ (للأدمن)
export const getAllPropertyHistory = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res.status(403).json({
        message: "Only admin can view all property history",
      });
    }

    const histories = await PropertyHistory.find()
      .populate("performedBy", "name email")
      .populate("propertyId", "title address")
      .sort({ createdAt: -1 })
      .limit(100); // حد أقصى

    res.status(200).json(histories);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property history",
      error: error.message,
    });
  }
};

