// controllers/userController.js

import User from "../models/User.js";
import Chat from "../models/Chat.js"; // ✅ (1) تم إضافة هذا الاستيراد
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

/* ========================================================
   Register User
======================================================== */
export const registerUser = async (req, res) => {
  try {
    const { name, email, phone, role, password } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: "User already exists" });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = new User({
      name,
      email,
      phone,
      role,
      passwordHash,
      profilePicture: "", // default
    });

    await user.save();

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(201).json({
      message: "✅ User registered successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        profilePicture: user.profilePicture,
      },
      token,
    });

  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

/* ========================================================
   Login User
======================================================== */
export const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) return res.status(400).json({ message: "Invalid credentials" });

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.status(200).json({
      message: "✅ Login successful",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        profilePicture: user.profilePicture,
      },
      token,
    });

  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

/* ========================================================
   Get Logged-in User Data (GET /me)
======================================================== */
export const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-passwordHash");

    if (!user) return res.status(404).json({ message: "User not found" });

    res.status(200).json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        profilePicture: user.profilePicture,
      },
    });

  } catch (error) {
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

/* ========================================================
   Update Profile Picture
======================================================== */
export const updateUserProfile = async (req, res) => {
  try {
    const { profilePicture } = req.body;

    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: "User not found" });

    if (profilePicture) {
      user.profilePicture = profilePicture;
    }

    await user.save();

    res.status(200).json({
      message: "✅ Profile updated successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        profilePicture: user.profilePicture,
      },
    });

  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

/* ========================================================
   Get Users for Chat List + Unread Counts (GET /api/users/chat-list)
   ✅ (2) تم تعديل هذه الدالة بالكامل
======================================================== */
export const getUsersForChat = async (req, res) => {
  try {
    const currentUserId = req.user._id;

    // جلب المستخدمين (ما عدا أنا) باستخدام .lean() للتمكن من تعديل الكائن
    const users = await User.find({ _id: { $ne: currentUserId } })
      .select("name email role profilePicture")
      .lean();

    // إضافة عدد الرسائل غير المقروءة لكل مستخدم
    for (let user of users) {
      const unreadCount = await Chat.countDocuments({
        senderId: user._id,       // المرسل هو المستخدم الآخر
        receiverId: currentUserId, // المستقبل هو أنا
        isRead: false             // الرسالة لم تقرأ بعد
      });
      
      user.unreadCount = unreadCount;
    }

    // (اختياري) ترتيب المستخدمين بحيث يظهر من لديه رسائل غير مقروءة أولاً
    users.sort((a, b) => b.unreadCount - a.unreadCount);

    res.status(200).json({
      success: true,
      users,
    });

  } catch (error) {
    res.status(500).json({
      message: "Error fetching users",
      error: error.message,
    });
  }
};