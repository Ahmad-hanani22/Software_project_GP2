import User from "../models/User.js";
import Chat from "../models/Chat.js";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import {
  sendLoginNotification,
  sendVerificationEmail,
} from "../utils/emailService.js";

/* ============================
   Register User
============================ */
export const registerUser = async (req, res) => {
  try {
    const { name, email, password, phone, role } = req.body;

    const exists = await User.findOne({ email });
    if (exists) {
      return res.status(400).json({ message: "User already exists" });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const verificationToken = crypto.randomBytes(32).toString("hex");

    const user = await User.create({
      name,
      email,
      phone,
      role,
      passwordHash,
      isVerified: false,
      verificationToken,
    });

    await sendVerificationEmail(user.email, verificationToken);

    res.status(201).json({
      message: "Account created. Please check your email to verify.",
    });
  } catch (err) {
    res.status(500).json({ message: "Register error", error: err.message });
  }
};

/* ============================
   Login User
============================ */
export const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "User not found" });

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(400).json({ message: "Invalid credentials" });

    if (!user.isVerified) {
      return res.status(403).json({
        message: "Your account is not verified. Check your email.",
      });
    }

    const token = jwt.sign(
      { id: user._id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    sendLoginNotification(user.email, user.name);

    res.json({
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    res.status(500).json({ message: "Login error", error: err.message });
  }
};

/* ============================
   Verify Email
============================ */
export const verifyUserEmail = async (req, res) => {
  try {
    const { token } = req.params;

    const user = await User.findOne({ verificationToken: token });
    if (!user) {
      return res.status(400).send("<h2>❌ Invalid or expired link</h2>");
    }

    user.isVerified = true;
    user.verificationToken = undefined;
    await user.save();

    res.send(`
      <h1 style="color:green;text-align:center">
        ✅ Account verified successfully
      </h1>
    `);
  } catch {
    res.status(500).send("Verification error");
  }
};

/* ============================
   Get Current User
============================ */
export const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select("-passwordHash");
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: "Server error" });
  }
};

/* ============================
   Update User Profile  ✅ (الجديد)
============================ */
export const updateUserProfile = async (req, res) => {
  try {
    const { name, phone, profilePicture } = req.body;

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (name) user.name = name;
    if (phone) user.phone = phone;
    if (profilePicture) user.profilePicture = profilePicture;

    await user.save();

    res.json({
      message: "Profile updated successfully",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        profilePicture: user.profilePicture,
      },
    });
  } catch (error) {
    res.status(500).json({ message: "Update profile error" });
  }
};

/* ============================
   Get Users For Chat (with unread count)
============================ */
export const getUsersForChat = async (req, res) => {
  try {
    const currentUserId = req.user._id;
    
    // Get all users except current user
    const users = await User.find({
      _id: { $ne: currentUserId },
    }).select("name email profilePicture role");

    // Get unread counts for each user
    const usersWithUnread = await Promise.all(
      users.map(async (user) => {
        const unreadCount = await Chat.countDocuments({
          senderId: user._id,
          receiverId: currentUserId,
          isRead: false,
        });
        
        // Get last message time for sorting
        const lastMessage = await Chat.findOne({
          $or: [
            { senderId: user._id, receiverId: currentUserId },
            { senderId: currentUserId, receiverId: user._id },
          ],
        })
          .sort({ createdAt: -1 })
          .select("createdAt");

        return {
          _id: user._id,
          name: user.name,
          email: user.email,
          profilePicture: user.profilePicture,
          role: user.role,
          unreadCount,
          lastMessageTime: lastMessage?.createdAt || new Date(0),
        };
      })
    );

    // Sort by unread count (descending) then by last message time (descending)
    usersWithUnread.sort((a, b) => {
      if (b.unreadCount !== a.unreadCount) {
        return b.unreadCount - a.unreadCount;
      }
      return new Date(b.lastMessageTime) - new Date(a.lastMessageTime);
    });

    res.json(usersWithUnread);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

/* ============================
   Get Admin Users (for chat)
============================ */
export const getAdminUsers = async (req, res) => {
  try {
    const admins = await User.find({ role: "admin" })
      .select("_id name email profilePicture")
      .limit(10); // Get first 10 admins

    res.json(admins);
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

/* ============================
   Register FCM Token 🔔
============================ */
export const registerFCMToken = async (req, res) => {
  try {
    const { userId } = req.params;
    const { fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ message: "fcmToken is required" });
    }

    // التحقق من أن المستخدم موجود
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // التحقق من أن المستخدم يحاول تحديث token الخاص به فقط
    // تحويل إلى string للمقارنة
    const currentUserId = req.user.id?.toString() || req.user._id?.toString();
    const targetUserId = userId.toString();
    
    if (currentUserId !== targetUserId) {
      return res.status(403).json({ message: "Unauthorized" });
    }

    // تحديث FCM Token
    user.fcmToken = fcmToken;
    await user.save();

    res.status(200).json({
      message: "FCM Token registered successfully",
      fcmToken: user.fcmToken,
    });
  } catch (error) {
    console.error("Error registering FCM token:", error);
    res.status(500).json({
      message: "Error registering FCM token",
      error: error.message,
    });
  }
};