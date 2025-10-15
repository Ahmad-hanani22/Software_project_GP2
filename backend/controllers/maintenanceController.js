import MaintenanceRequest from "../models/MaintenanceRequest.js";
import Property from "../models/Property.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";

/* =========================================================
 🧰 إنشاء طلب صيانة (Tenant فقط)
========================================================= */
export const createMaintenance = async (req, res) => {
  try {
    // ✅ تأكد أن المستخدم Tenant فقط
    if (req.user.role !== "tenant") {
      return res
        .status(403)
        .json({ message: "🚫 Only tenants can create maintenance requests" });
    }

    const { propertyId, description, images } = req.body;

    // ✅ تحقق من القيم الأساسية
    if (!propertyId || !description) {
      return res
        .status(400)
        .json({ message: "❌ propertyId and description are required" });
    }

    // ✅ تحقق من وجود العقار
    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "❌ Property not found" });
    }

    // ✅ إنشاء الطلب
    const maintenance = new MaintenanceRequest({
      propertyId,
      tenantId: req.user._id,
      description: description.trim(),
      images: images || [],
      status: "pending",
    });

    await maintenance.save();

    // 🔔 إرسال إشعارات بعد الحفظ
    // 1. للمستأجر نفسه
    await sendNotification({
      userId: req.user._id,
      message: "✅ تم إرسال طلب الصيانة الخاص بك بنجاح",
      type: "maintenance",
      actorId: req.user._id,
      entityType: "maintenance",
      entityId: maintenance._id,
      link: `/maintenance/${maintenance._id}`,
    });

    // 2. للمالك إذا كان موجود
    const prop = await Property.findById(maintenance.propertyId).select(
      "ownerId"
    );
    if (prop?.ownerId) {
      await sendNotification({
        userId: prop.ownerId,
        message: "📥 وصلك طلب صيانة جديد من مستأجر",
        type: "maintenance",
        actorId: req.user._id,
        entityType: "maintenance",
        entityId: maintenance._id,
        link: `/maintenance/${maintenance._id}`,
      });
    }

    // 3. إشعار للأدمن لمراقبة الطلبات
    await notifyAdmins({
      message: "🛠️ تم إنشاء طلب صيانة جديد من أحد المستأجرين",
      type: "maintenance",
      actorId: req.user._id,
      entityType: "maintenance",
      entityId: maintenance._id,
      link: `/maintenance/${maintenance._id}`,
    });

    res.status(201).json({
      message: "✅ Maintenance request created successfully",
      maintenance,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error creating maintenance request",
      error: error.message,
    });
  }
};

/* =========================================================
 📋 عرض جميع طلبات الصيانة (Admin فقط)
========================================================= */
export const getMaintenances = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "🚫 Only admin can view all maintenance requests" });
    }

    const maintenances = await MaintenanceRequest.find()
      .populate("propertyId tenantId", "title name email phone")
      .sort({ createdAt: -1 });

    res.status(200).json(maintenances);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching maintenance requests",
      error: error.message,
    });
  }
};

/* =========================================================
 👤 عرض طلبات مستأجر (نفسه أو أدمن)
========================================================= */
export const getTenantRequests = async (req, res) => {
  try {
    const tenantId = req.params.tenantId;

    // 🔐 تحقق من الصلاحية
    if (
      req.user.role !== "admin" &&
      String(req.user._id) !== String(tenantId)
    ) {
      return res.status(403).json({
        message: "🚫 You can only view your own maintenance requests",
      });
    }

    const maintenances = await MaintenanceRequest.find({ tenantId })
      .populate("propertyId", "title address price")
      .sort({ createdAt: -1 });

    res.status(200).json(maintenances);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching tenant maintenance requests",
      error: error.message,
    });
  }
};

/* =========================================================
 🏠 عرض طلبات صيانة لعقار (مالك أو أدمن)
========================================================= */
export const getPropertyRequests = async (req, res) => {
  try {
    const { propertyId } = req.params;
    const property = await Property.findById(propertyId).select("ownerId");

    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });

    // 🔐 السماح للمالك أو الأدمن فقط
    if (
      String(property.ownerId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res
        .status(403)
        .json({ message: "🚫 Access denied: owner or admin only" });
    }

    const maintenances = await MaintenanceRequest.find({ propertyId })
      .populate("tenantId", "name email phone")
      .sort({ createdAt: -1 });

    res.status(200).json(maintenances);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property maintenance requests",
      error: error.message,
    });
  }
};

/* =========================================================
 🔧 تحديث حالة الطلب (Landlord/Admin)
========================================================= */
export const updateMaintenance = async (req, res) => {
  try {
    if (!["landlord", "admin"].includes(req.user.role)) {
      return res
        .status(403)
        .json({ message: "🚫 Only landlord or admin can update maintenance" });
    }

    const { status, description } = req.body;
    const maintenance = await MaintenanceRequest.findById(req.params.id);

    if (!maintenance)
      return res
        .status(404)
        .json({ message: "❌ Maintenance request not found" });

    if (status) maintenance.status = status;
    if (description) maintenance.description = description.trim();

    await maintenance.save();

    // 🔔 إشعار للمستأجر بعد التحديث
    await sendNotification({
      userId: maintenance.tenantId,
      message: `🔄 تم تحديث حالة طلب الصيانة إلى: ${maintenance.status}`,
      type: "maintenance",
      actorId: req.user._id,
      entityType: "maintenance",
      entityId: maintenance._id,
      link: `/maintenance/${maintenance._id}`,
    });

    res.status(200).json({
      message: "✅ Maintenance request updated successfully",
      maintenance,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating maintenance request",
      error: error.message,
    });
  }
};

/* =========================================================
 👷 تعيين فني للطلب (Landlord/Admin)
========================================================= */
export const assignTechnician = async (req, res) => {
  try {
    const { technicianName } = req.body;

    if (!["landlord", "admin"].includes(req.user.role)) {
      return res
        .status(403)
        .json({ message: "🚫 Only landlord or admin can assign technician" });
    }

    const maintenance = await MaintenanceRequest.findById(req.params.id);
    if (!maintenance)
      return res
        .status(404)
        .json({ message: "❌ Maintenance request not found" });

    maintenance.technicianName = technicianName;
    maintenance.status = "in_progress";
    await maintenance.save();

    // 🔔 إشعار للمستأجر عند تعيين فني
    await sendNotification({
      userId: maintenance.tenantId,
      message: `👷 تم تعيين فني (${technicianName}) لمعالجة طلب الصيانة`,
      type: "maintenance",
      actorId: req.user._id,
      entityType: "maintenance",
      entityId: maintenance._id,
      link: `/maintenance/${maintenance._id}`,
    });

    res.status(200).json({
      message: "✅ Technician assigned successfully",
      maintenance,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error assigning technician",
      error: error.message,
    });
  }
};

/* =========================================================
 🖼️ إضافة صورة (Tenant فقط)
========================================================= */
export const addImageToRequest = async (req, res) => {
  try {
    if (req.user.role !== "tenant") {
      return res.status(403).json({
        message: "🚫 Only tenant can add images to maintenance request",
      });
    }

    const { imageUrl } = req.body;
    const maintenance = await MaintenanceRequest.findById(req.params.id);
    if (!maintenance)
      return res
        .status(404)
        .json({ message: "❌ Maintenance request not found" });

    maintenance.images.push(imageUrl);
    await maintenance.save();

    res.status(200).json({
      message: "✅ Image added successfully",
      maintenance,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error adding image",
      error: error.message,
    });
  }
};

/* =========================================================
 ❌ حذف طلب صيانة (صاحب الطلب أو أدمن)
========================================================= */
export const deleteMaintenance = async (req, res) => {
  try {
    const maintenance = await MaintenanceRequest.findById(req.params.id);
    if (!maintenance)
      return res
        .status(404)
        .json({ message: "❌ Maintenance request not found" });

    // 🔐 تحقق من الصلاحية
    if (
      String(maintenance.tenantId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "🚫 You can only delete your own maintenance requests",
      });
    }

    await maintenance.deleteOne();

    res.status(200).json({
      message: "✅ Maintenance request deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting maintenance request",
      error: error.message,
    });
  }
};
