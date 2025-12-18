import Building from "../models/Building.js";
import Property from "../models/Property.js";

// 1. إنشاء مبنى جديد
export const addBuilding = async (req, res) => {
  try {
    const building = new Building({
      ...req.body,
      ownerId: req.user._id,
    });
    await building.save();

    res.status(201).json({
      message: "✅ Building created successfully",
      building,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error creating building",
      error: error.message,
    });
  }
};

// 2. جلب جميع المباني
export const getAllBuildings = async (req, res) => {
  try {
    const filter = {};
    
    // إذا لم يكن أدمن، عرض فقط مباني المستخدم
    if (req.user.role !== "admin") {
      filter.ownerId = req.user._id;
    }

    const buildings = await Building.find(filter)
      .populate("ownerId", "name email")
      .sort({ createdAt: -1 });

    res.status(200).json(buildings);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching buildings",
      error: error.message,
    });
  }
};

// 3. جلب مبنى محدد
export const getBuildingById = async (req, res) => {
  try {
    const building = await Building.findById(req.params.id)
      .populate("ownerId", "name email");

    if (!building) {
      return res.status(404).json({ message: "Building not found" });
    }

    // جلب العقارات المرتبطة بالمبنى (إذا كان هناك رابط)
    const properties = await Property.find({
      // يمكن إضافة رابط بين Building و Property لاحقاً
    }).limit(10);

    res.status(200).json({
      building,
      properties,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching building",
      error: error.message,
    });
  }
};

// 4. تحديث مبنى
export const updateBuilding = async (req, res) => {
  try {
    const building = await Building.findById(req.params.id);
    if (!building) {
      return res.status(404).json({ message: "Building not found" });
    }

    // التحقق من الصلاحيات
    if (
      String(building.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to update this building",
      });
    }

    const updatedBuilding = await Building.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    res.status(200).json({
      message: "✅ Building updated successfully",
      building: updatedBuilding,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating building",
      error: error.message,
    });
  }
};

// 5. حذف مبنى
export const deleteBuilding = async (req, res) => {
  try {
    const building = await Building.findById(req.params.id);
    if (!building) {
      return res.status(404).json({ message: "Building not found" });
    }

    // التحقق من الصلاحيات
    if (
      String(building.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to delete this building",
      });
    }

    await Building.findByIdAndDelete(req.params.id);

    res.status(200).json({ message: "🗑️ Building deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting building",
      error: error.message,
    });
  }
};

