// controllers/adminController.js
import Admin from "../models/Admin.js";
import User from "../models/User.js";
import bcrypt from "bcryptjs";

export const createAdmin = async (req, res) => {
  try {
    const { userId, roleTitle, permissions, createdBy } = req.body;

    const existing = await Admin.findOne({ userId });
    if (existing) {
      return res
        .status(400)
        .json({ message: "Admin already exists for this user" });
    }

    const admin = new Admin({ userId, roleTitle, permissions, createdBy });
    await admin.save();
    res.status(201).json({ message: "✅ Admin created successfully", admin });
  } catch (error) {
    console.error("❌ Error creating admin:", error);
    res
      .status(500)
      .json({ message: "❌ Error creating admin", error: error.message });
  }
};

export const getAllAdmins = async (req, res) => {
  try {
    const admins = await Admin.find()
      .populate("userId", "name email role")
      .populate("createdBy", "name email");
    res.status(200).json(admins);
  } catch (error) {
    console.error("❌ Error fetching all admins:", error);
    res
      .status(500)
      .json({ message: "❌ Error fetching admins", error: error.message });
  }
};

export const getAllUsers = async (req, res) => {
  try {
    const users = await User.find().select("-passwordHash");
    res.status(200).json(users);
  } catch (error) {
    console.error("❌ Error fetching all users for admin:", error);
    res
      .status(500)
      .json({ message: "❌ Error fetching users", error: error.message });
  }
};

export const createUserByAdmin = async (req, res) => {
  try {
    const { name, email, role, password, phone } = req.body;

    if (!name || !email || !password) {
      return res
        .status(400)
        .json({ message: "name, email, password are required" });
    }

    const allowedRoles = ["admin", "landlord", "tenant"];
    if (role && !allowedRoles.includes(role)) {
      return res.status(400).json({ message: "Invalid role value" });
    }

    const existing = await User.findOne({ email });
    if (existing)
      return res.status(400).json({ message: "Email already in use" });

    const passwordHash = await bcrypt.hash(password, 10);

    const user = new User({
      name,
      email,
      phone: phone || "",
      role: role || "tenant",
      passwordHash,
    });

    await user.save();

    res.status(201).json({
      message: "✅ User created successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error("❌ Error creating user by admin:", error);
    res
      .status(500)
      .json({ message: "❌ Error creating user", error: error.message });
  }
};

export const updateUserByAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, role, phone, password } = req.body;

    const user = await User.findById(id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (email && email !== user.email) {
      const exists = await User.findOne({ email });
      if (exists)
        return res.status(400).json({ message: "Email already in use" });
      user.email = email;
    }

    if (name) user.name = name;
    if (phone !== undefined) user.phone = phone;

    if (role) {
      const allowedRoles = ["admin", "landlord", "tenant"];
      if (!allowedRoles.includes(role)) {
        return res.status(400).json({ message: "Invalid role value" });
      }
      user.role = role;
    }

    if (password && password.trim().length >= 6) {
      user.passwordHash = await bcrypt.hash(password.trim(), 10);
    }

    await user.save();

    res.status(200).json({
      message: "✅ User updated successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error("❌ Error updating user by admin:", error);
    res
      .status(500)
      .json({ message: "❌ Error updating user", error: error.message });
  }
};

//  حذف مستخدم بواسطة الأدمن
export const deleteUserByAdmin = async (req, res) => {
  try {
    const { id } = req.params;

    // منع حذف نفسه
    if (String(req.user._id) === String(id)) {
      return res.status(400).json({ message: "You cannot delete yourself" });
    }

    const deleted = await User.findByIdAndDelete(id);
    if (!deleted) return res.status(404).json({ message: "User not found" });

    res.status(200).json({ message: "🗑️ User deleted successfully" });
  } catch (error) {
    console.error("❌ Error deleting user by admin:", error);
    res
      .status(500)
      .json({ message: "❌ Error deleting user", error: error.message });
  }
};

export const updateAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await Admin.findByIdAndUpdate(id, req.body, { new: true });
    if (!updated)
      return res.status(404).json({ message: "Admin entry not found" });
    res
      .status(200)
      .json({ message: "✅ Admin privileges updated successfully", updated });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error updating admin", error: error.message });
  }
};

export const deleteAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Admin.findByIdAndDelete(id);
    if (!deleted)
      return res.status(404).json({ message: "Admin entry not found" });
    res.status(200).json({ message: "🗑️ Admin entry deleted successfully" });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error deleting admin", error: error.message });
  }
};

export const checkPermission = async (req, res) => {
  try {
    const { userId, feature } = req.body;
    const admin = await Admin.findOne({ userId });
    if (!admin)
      return res
        .status(404)
        .json({ message: "Admin not found for this user ID" });

    const hasPermission =
      admin.permissions && admin.permissions[feature] === true;

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
