// controllers/propertyTypeController.js
import PropertyType from "../models/PropertyType.js";
import Property from "../models/Property.js";
import { validationResult } from "express-validator";

// 📋 الحصول على جميع أنواع العقارات
export const getAllPropertyTypes = async (req, res) => {
  try {
    const { activeOnly = "true" } = req.query;
    
    const query = activeOnly === "true" ? { isActive: true } : {};
    
    const types = await PropertyType.find(query)
      .sort({ order: 1, createdAt: 1 })
      .select("-__v");
    
    res.status(200).json({
      success: true,
      count: types.length,
      data: types,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to fetch property types",
      error: error.message,
    });
  }
};

// 📋 الحصول على نوع عقار واحد
export const getPropertyTypeById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const type = await PropertyType.findById(id);
    
    if (!type) {
      return res.status(404).json({
        success: false,
        message: "❌ Property type not found",
      });
    }
    
    res.status(200).json({
      success: true,
      data: type,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to fetch property type",
      error: error.message,
    });
  }
};

// ➕ إنشاء نوع عقار جديد
export const createPropertyType = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: "Validation error",
      errors: errors.array(),
    });
  }

  try {
    const { name, displayName, icon, description, order } = req.body;

    // التحقق من عدم وجود نوع بنفس الاسم
    const existingType = await PropertyType.findOne({ 
      name: name.toLowerCase().trim() 
    });
    
    if (existingType) {
      return res.status(400).json({
        success: false,
        message: "❌ Property type with this name already exists",
      });
    }

    const newType = new PropertyType({
      name: name.toLowerCase().trim(),
      displayName: displayName.trim(),
      icon: icon || "home",
      description: description?.trim(),
      order: order || 0,
      isActive: true,
    });

    await newType.save();

    res.status(201).json({
      success: true,
      message: "✅ Property type created successfully",
      data: newType,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to create property type",
      error: error.message,
    });
  }
};

// ✏️ تحديث نوع عقار
export const updatePropertyType = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: "Validation error",
      errors: errors.array(),
    });
  }

  try {
    const { id } = req.params;
    const { name, displayName, icon, description, order, isActive } = req.body;

    const type = await PropertyType.findById(id);
    
    if (!type) {
      return res.status(404).json({
        success: false,
        message: "❌ Property type not found",
      });
    }

    // إذا تم تغيير الاسم، التحقق من عدم التكرار
    if (name && name.toLowerCase().trim() !== type.name) {
      const existingType = await PropertyType.findOne({ 
        name: name.toLowerCase().trim(),
        _id: { $ne: id }
      });
      
      if (existingType) {
        return res.status(400).json({
          success: false,
          message: "❌ Property type with this name already exists",
        });
      }
    }

    // تحديث الحقول
    if (name) type.name = name.toLowerCase().trim();
    if (displayName) type.displayName = displayName.trim();
    if (icon !== undefined) type.icon = icon;
    if (description !== undefined) type.description = description?.trim();
    if (order !== undefined) type.order = order;
    if (isActive !== undefined) type.isActive = isActive;

    await type.save();

    res.status(200).json({
      success: true,
      message: "✅ Property type updated successfully",
      data: type,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to update property type",
      error: error.message,
    });
  }
};

// 🗑️ حذف نوع عقار
export const deletePropertyType = async (req, res) => {
  try {
    const { id } = req.params;

    const type = await PropertyType.findById(id);
    
    if (!type) {
      return res.status(404).json({
        success: false,
        message: "❌ Property type not found",
      });
    }

    // التحقق من وجود عقارات تستخدم هذا النوع
    const propertiesCount = await Property.countDocuments({ 
      type: type.name 
    });

    if (propertiesCount > 0) {
      return res.status(400).json({
        success: false,
        message: `❌ Cannot delete property type. There are ${propertiesCount} properties using this type. Please update or delete those properties first.`,
        propertiesCount,
      });
    }

    await PropertyType.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: "✅ Property type deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to delete property type",
      error: error.message,
    });
  }
};

// 🔄 تفعيل/تعطيل نوع عقار
export const togglePropertyTypeStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const type = await PropertyType.findById(id);
    
    if (!type) {
      return res.status(404).json({
        success: false,
        message: "❌ Property type not found",
      });
    }

    type.isActive = !type.isActive;
    await type.save();

    res.status(200).json({
      success: true,
      message: `✅ Property type ${type.isActive ? "activated" : "deactivated"} successfully`,
      data: type,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to toggle property type status",
      error: error.message,
    });
  }
};

// 📊 إحصائيات أنواع العقارات
export const getPropertyTypeStats = async (req, res) => {
  try {
    const types = await PropertyType.find({ isActive: true });
    
    const stats = await Promise.all(
      types.map(async (type) => {
        const count = await Property.countDocuments({ type: type.name });
        return {
          type: type.name,
          displayName: type.displayName,
          count,
        };
      })
    );

    res.status(200).json({
      success: true,
      data: stats,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to fetch property type statistics",
      error: error.message,
    });
  }
};

