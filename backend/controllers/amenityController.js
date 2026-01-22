// controllers/amenityController.js
import Amenity from "../models/Amenity.js";
import Property from "../models/Property.js";
import Unit from "../models/Unit.js";
import Building from "../models/Building.js";
import { validationResult } from "express-validator";

// 📋 الحصول على جميع المميزات
export const getAllAmenities = async (req, res) => {
  try {
    const { activeOnly = "true" } = req.query;
    
    const query = activeOnly === "true" ? { isActive: true } : {};
    
    const amenities = await Amenity.find(query)
      .sort({ order: 1, createdAt: 1 })
      .select("-__v");
    
    res.status(200).json({
      success: true,
      count: amenities.length,
      data: amenities,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to fetch amenities",
      error: error.message,
    });
  }
};

// 📋 الحصول على مميزة واحدة
export const getAmenityById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const amenity = await Amenity.findById(id);
    
    if (!amenity) {
      return res.status(404).json({
        success: false,
        message: "❌ Amenity not found",
      });
    }
    
    res.status(200).json({
      success: true,
      data: amenity,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to fetch amenity",
      error: error.message,
    });
  }
};

// ➕ إنشاء مميزة جديدة
export const createAmenity = async (req, res) => {
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

    // التحقق من عدم وجود مميزة بنفس الاسم
    const existingAmenity = await Amenity.findOne({ 
      name: name.toLowerCase().trim() 
    });
    
    if (existingAmenity) {
      return res.status(400).json({
        success: false,
        message: "❌ Amenity with this name already exists",
      });
    }

    const newAmenity = new Amenity({
      name: name.toLowerCase().trim(),
      displayName: displayName.trim(),
      icon: icon || "check_circle",
      description: description?.trim(),
      order: order || 0,
      isActive: true,
    });

    await newAmenity.save();

    res.status(201).json({
      success: true,
      message: "✅ Amenity created successfully",
      data: newAmenity,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to create amenity",
      error: error.message,
    });
  }
};

// ✏️ تحديث مميزة
export const updateAmenity = async (req, res) => {
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

    const amenity = await Amenity.findById(id);
    
    if (!amenity) {
      return res.status(404).json({
        success: false,
        message: "❌ Amenity not found",
      });
    }

    // إذا تم تغيير الاسم، التحقق من عدم التكرار
    if (name && name.toLowerCase().trim() !== amenity.name) {
      const existingAmenity = await Amenity.findOne({ 
        name: name.toLowerCase().trim(),
        _id: { $ne: id }
      });
      
      if (existingAmenity) {
        return res.status(400).json({
          success: false,
          message: "❌ Amenity with this name already exists",
        });
      }
    }

    // تحديث الحقول
    if (name) amenity.name = name.toLowerCase().trim();
    if (displayName) amenity.displayName = displayName.trim();
    if (icon !== undefined) amenity.icon = icon;
    if (description !== undefined) amenity.description = description?.trim();
    if (order !== undefined) amenity.order = order;
    if (isActive !== undefined) amenity.isActive = isActive;

    await amenity.save();

    res.status(200).json({
      success: true,
      message: "✅ Amenity updated successfully",
      data: amenity,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to update amenity",
      error: error.message,
    });
  }
};

// 🗑️ حذف مميزة
export const deleteAmenity = async (req, res) => {
  try {
    const { id } = req.params;

    const amenity = await Amenity.findById(id);
    
    if (!amenity) {
      return res.status(404).json({
        success: false,
        message: "❌ Amenity not found",
      });
    }

    // التحقق من وجود عقارات/وحدات/مباني تستخدم هذه المميزة
    const amenityName = amenity.displayName;
    
    const propertiesCount = await Property.countDocuments({ 
      amenities: amenityName 
    });
    
    const unitsCount = await Unit.countDocuments({ 
      amenities: amenityName 
    });
    
    const buildingsCount = await Building.countDocuments({ 
      amenities: amenityName 
    });

    const totalCount = propertiesCount + unitsCount + buildingsCount;

    if (totalCount > 0) {
      return res.status(400).json({
        success: false,
        message: `❌ Cannot delete amenity. It is used in ${totalCount} properties/units/buildings. Please remove it from those entities first.`,
        usage: {
          properties: propertiesCount,
          units: unitsCount,
          buildings: buildingsCount,
        },
      });
    }

    await Amenity.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: "✅ Amenity deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to delete amenity",
      error: error.message,
    });
  }
};

// 🔄 تفعيل/تعطيل مميزة
export const toggleAmenityStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const amenity = await Amenity.findById(id);
    
    if (!amenity) {
      return res.status(404).json({
        success: false,
        message: "❌ Amenity not found",
      });
    }

    amenity.isActive = !amenity.isActive;
    await amenity.save();

    res.status(200).json({
      success: true,
      message: `✅ Amenity ${amenity.isActive ? "activated" : "deactivated"} successfully`,
      data: amenity,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "❌ Failed to toggle amenity status",
      error: error.message,
    });
  }
};

// 📊 إحصائيات المميزات
export const getAmenityStats = async (req, res) => {
  try {
    const amenities = await Amenity.find({ isActive: true });
    
    const stats = await Promise.all(
      amenities.map(async (amenity) => {
        const amenityName = amenity.displayName;
        
        const propertiesCount = await Property.countDocuments({ 
          amenities: amenityName 
        });
        
        const unitsCount = await Unit.countDocuments({ 
          amenities: amenityName 
        });
        
        const buildingsCount = await Building.countDocuments({ 
          amenities: amenityName 
        });
        
        return {
          amenity: amenity.name,
          displayName: amenity.displayName,
          usage: {
            properties: propertiesCount,
            units: unitsCount,
            buildings: buildingsCount,
            total: propertiesCount + unitsCount + buildingsCount,
          },
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
      message: "❌ Failed to fetch amenity statistics",
      error: error.message,
    });
  }
};
