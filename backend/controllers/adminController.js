import Admin from "../models/Admin.js";
import User from "../models/User.js";

// ✅ إنشاء أدمن جديد
export const createAdmin = async (req, res) => {
  try {
    const { userId, roleTitle, permissions, createdBy } = req.body;

    const existing = await Admin.findOne({ userId });
    if (existing)
      return res.status(400).json({ message: "Admin already exists" });

    const admin = new Admin({
      userId,
      roleTitle,
      permissions,
      createdBy,
    });

    await admin.save();
    res.status(201).json({ message: "✅ Admin created successfully", admin });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error creating admin", error: error.message });
  }
};

// ✅ عرض كل الأدمنز
export const getAllAdmins = async (req, res) => {
  try {
    const admins = await Admin.find()
      .populate("userId", "name email role")
      .populate("createdBy", "name email");
    res.status(200).json(admins);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching admins", error: error.message });
  }
};

// ✅ تحديث صلاحيات أو الدور
export const updateAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await Admin.findByIdAndUpdate(id, req.body, { new: true });
    if (!updated) return res.status(404).json({ message: "Admin not found" });
    res.status(200).json({ message: "✅ Admin updated successfully", updated });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error updating admin", error: error.message });
  }
};

// ✅ حذف أدمن
export const deleteAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Admin.findByIdAndDelete(id);
    if (!deleted) return res.status(404).json({ message: "Admin not found" });
    res.status(200).json({ message: "🗑️ Admin deleted successfully" });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error deleting admin", error: error.message });
  }
};

// ✅ التحقق من صلاحيات الأدمن
export const checkPermission = async (req, res) => {
  try {
    const { userId, feature } = req.body; // example: { "userId": "...", "feature": "properties" }

    const admin = await Admin.findOne({ userId });
    if (!admin) return res.status(404).json({ message: "Admin not found" });

    const hasPermission = admin.permissions[feature] === true;

    res.status(200).json({
      message: hasPermission ? "✅ Access granted" : "🚫 Access denied",
      role: admin.roleTitle,
      feature,
      permission: hasPermission,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error checking permission", error: error.message });
  }
};
