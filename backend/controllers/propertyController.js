// controllers/propertyController.js
import Property from "../models/Property.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";

export const addProperty = async (req, res) => {
  try {
    if (!["landlord", "admin"].includes(req.user.role)) {
      return res
        .status(403)
        .json({ message: "🚫 Only landlord or admin can add properties" });
    }

    const property = new Property({
      ...req.body,
      ownerId: req.user._id,
    });
    await property.save();

    await notifyAdmins({
      title: "🏠 عقار جديد",
      message: `تم إضافة عقار جديد من ${req.user.role === "landlord" ? "مالك" : "أدمن"
        }`,
      type: "property",
      actorId: req.user._id,
      entityType: "property",
      entityId: property._id,
      link: `/admin/properties/${property._id}`,
    });

    res.status(201).json({
      message: "✅ Property added successfully",
      property,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error adding property", error: error.message });
  }
};

export const getAllProperties = async (req, res) => {
  try {
    console.log("🔹 Fetching all properties...");
    const { type, operation, city, minPrice, maxPrice } = req.query;

    const query = {
      status: "available", // ✅ العامة تشوف المتاح فقط
    };

    if (type) query.type = type;
    if (operation) query.operation = operation;
    if (city) query.city = new RegExp(city, "i");

    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    }

    console.log("🔹 Query:", JSON.stringify(query));

    const properties = await Property.find(query)
      .populate("ownerId", "name email")
      .sort({ createdAt: -1 })
      .lean();

    console.log(`✅ Found ${properties.length} properties`);
    res.status(200).json(properties);
  } catch (error) {
    console.error("❌ Error fetching public properties:", error);
    res.status(500).json({
      message: "Error fetching properties",
      error: error.message, // Send error details to client for debugging
    });
  }
};


export const getPropertyById = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id).populate(
      "ownerId",
      "name email phone"
    );
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });
    res.status(200).json(property);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property",
      error: error.message,
    });
  }
};

export const getPropertiesByOwner = async (req, res) => {
  try {
    const { ownerId } = req.params;
    if (req.user.role !== "admin" && String(req.user._id) !== String(ownerId)) {
      return res.status(403).json({
        message: "🚫 You can only view your own properties",
      });
    }

    const properties = await Property.find({ ownerId }).sort({ createdAt: -1 });
    res.status(200).json(properties);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching owner properties",
      error: error.message,
    });
  }
};

export const updateProperty = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id);
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });

    if (
      req.user.role !== "admin" &&
      String(property.ownerId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        message: "🚫 You can only update your own properties",
      });
    }

    Object.assign(property, req.body);
    await property.save();

    await notifyAdmins({
      title: "✏️ تحديث عقار",
      message: `تم تعديل تفاصيل عقار (${property.title}) من ${req.user.role}`,
      type: "property",
      actorId: req.user._id,
      entityType: "property",
      entityId: property._id,
      link: `/admin/properties/${property._id}`,
    });

    res.status(200).json({ message: "✅ Property updated", property });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating property",
      error: error.message,
    });
  }
};

export const deleteProperty = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id);
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });

    if (
      req.user.role !== "admin" &&
      String(property.ownerId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        message: "🚫 You can only delete your own properties",
      });
    }

    await property.deleteOne();

    await notifyAdmins({
      title: "🗑️ حذف عقار",
      message: `تم حذف عقار (${property.title}) من النظام`,
      type: "property",
      actorId: req.user._id,
      entityType: "property",
      entityId: property._id,
      link: `/admin/properties`,
    });

    res.status(200).json({ message: "🗑️ Property deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting property",
      error: error.message,
    });
  }
};
