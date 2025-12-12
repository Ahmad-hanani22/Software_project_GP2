import User from "../models/User.js";
import Chat from "../models/Chat.js";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "crypto"; // لتوليد توكن عشوائي
import { sendLoginNotification, sendVerificationEmail } from "../utils/emailService.js";

/* ========================================================
   Register User (مع التفعيل)
======================================================== */
export const registerUser = async (req, res) => {
  console.log("👉 1. Registration Request Started for:", req.body.email); // تتبع

  try {
    const { name, email, phone, role, password } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      console.log("❌ User already exists");
      return res.status(400).json({ message: "User already exists" });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    
    // إنشاء التوكن
    const verificationToken = crypto.randomBytes(32).toString("hex");

    const user = new User({
      name,
      email,
      phone,
      role,
      passwordHash,
      profilePicture: "",
      isVerified: false, 
      verificationToken: verificationToken
    });

    console.log("👉 2. Saving User to DB...");
    await user.save();
    console.log("✅ User Saved Successfully!");

    // محاولة إرسال الإيميل
    console.log("👉 3. Sending Verification Email...");
    try {
        await sendVerificationEmail(user.email, verificationToken);
        console.log("✅ Email sent successfully");
    } catch (emailError) {
        console.error("❌ Failed to send email:", emailError.message);
        // لن نوقف التسجيل، لكن سنعرف أن الإيميل فشل
    }

    res.status(201).json({
      message: "✅ Account created! Please check your email to verify your account.",
    });

  } catch (error) {
    console.error("🔥 Registration Error:", error);
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

/* ========================================================
   Login User (فحص التفعيل)
======================================================== */
export const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "User not found" });

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) return res.status(400).json({ message: "Invalid credentials" });

    // 👇👇 التحقق من تفعيل الإيميل 👇👇
    if (user.isVerified === false) {
      return res.status(403).json({ 
        message: "🚫 Your account is not verified. Please check your email." 
      });
    }

    const token = jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, { expiresIn: "7d" });

    sendLoginNotification(user.email, user.name);

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
   Verify User Email (الدالة الجديدة)
======================================================== */
export const verifyUserEmail = async (req, res) => {
  try {
    const { token } = req.params;

    // البحث عن المستخدم صاحب هذا التوكن
    const user = await User.findOne({ verificationToken: token });

    if (!user) {
      return res.status(400).send("<h1>❌ رابط التفعيل غير صالح أو منتهي.</h1>");
    }

    // تفعيل الحساب
    user.isVerified = true;
    user.verificationToken = undefined; // حذف التوكن لأنه استُخدم
    await user.save();

    // إرجاع صفحة HTML بسيطة للمستخدم
    res.send(`
      <div style="text-align: center; font-family: Arial; padding: 50px;">
        <h1 style="color: green;">✅ تم تفعيل الحساب بنجاح!</h1>
        <p>يمكنك الآن العودة للتطبيق وتسجيل الدخول.</p>
      </div>
    `);

  } catch (error) {
    res.status(500).send("<h1>Error verifying email</h1>");
  }
};

// ... (باقي الدوال getMe, updateUserProfile, getUsersForChat كما هي في الكود السابق)
export const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-passwordHash");
    if (!user) return res.status(404).json({ message: "User not found" });
    res.status(200).json({ success: true, user });
  } catch (error) {
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

export const updateUserProfile = async (req, res) => {
  try {
    const { profilePicture } = req.body;
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ message: "User not found" });
    if (profilePicture) user.profilePicture = profilePicture;
    await user.save();
    res.status(200).json({ message: "✅ Profile updated", user });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

export const getUsersForChat = async (req, res) => {
  try {
    const currentUserId = req.user._id;
    const users = await User.find({ _id: { $ne: currentUserId } }).select("name email role profilePicture").lean();
    for (let user of users) {
      const unreadCount = await Chat.countDocuments({ senderId: user._id, receiverId: currentUserId, isRead: false });
      user.unreadCount = unreadCount;
    }
    users.sort((a, b) => b.unreadCount - a.unreadCount);
    res.status(200).json({ success: true, users });
  } catch (error) {
    res.status(500).json({ message: "Error fetching users", error: error.message });
  }
};