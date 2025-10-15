import Property from "../models/Property.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";

/* =========================================================
 ➕ إضافة عقار جديد (Landlord فقط)
========================================================= */
export const addProperty = async (req, res) => {
  try {
    // ✅ السماح فقط للمالك أو الأدمن
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

    // 🔔 إشعار للأدمن بالمراجعة
    await notifyAdmins({
      message: `🏠 تم إضافة عقار جديد من ${
        req.user.role === "landlord" ? "مالك" : "أدمن"
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
    console.error("❌ Error adding property:", error);
    res
      .status(500)
      .json({ message: "❌ Error adding property", error: error.message });
  }
};

/* =========================================================
 📋 عرض جميع العقارات (Public + Admin view)
========================================================= */
export const getAllProperties = async (req, res) => {
  try {
    const properties = await Property.find()
      .populate("ownerId", "name email")
      .sort({ createdAt: -1 });

    res.status(200).json(properties);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching properties",
      error: error.message,
    });
  }
};

/* =========================================================
 🏠 عرض عقار واحد بالتفاصيل
========================================================= */
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

/* =========================================================
 👤 عرض عقارات مالك معيّن (لنفسه أو أدمن)
========================================================= */
export const getPropertiesByOwner = async (req, res) => {
  try {
    const { ownerId } = req.params;

    // 🔐 السماح فقط لنفس المالك أو الأدمن
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

/* =========================================================
 ✏️ تعديل العقار (Landlord/Admin)
========================================================= */
export const updateProperty = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id);
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });

    // 🔐 صلاحية: المالك أو الأدمن فقط
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

    // 🔔 إشعار للأدمن بالتعديل
    await notifyAdmins({
      message: `✏️ تم تعديل تفاصيل عقار (${property.title}) من ${req.user.role}`,
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

/* =========================================================
 🗑️ حذف العقار (Admin أو مالكه فقط)
========================================================= */
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

    // 🔔 إشعار للأدمن بالحذف
    await notifyAdmins({
      message: `🗑️ تم حذف عقار (${property.title}) من النظام`,
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
