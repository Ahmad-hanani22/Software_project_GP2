import express from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import User from "../models/User.js"; // تأكد من أن هذا المسار صحيح لموديل المستخدم الخاص بك

const router = express.Router();

// 🟢 تسجيل مستخدم جديد
router.post("/register", async (req, res) => {
  try {
    const { name, email, password, role } = req.body; // يمكن إضافة 'role' هنا إذا أردت تعيين دور عند التسجيل

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: "Email already registered" });
    }

    // 🔐 تشفير كلمة المرور
    const hashedPassword = await bcrypt.hash(password, 10);

    // ✅ نرسلها للحقل الصحيح passwordHash
    const user = await User.create({
      name,
      email,
      passwordHash: hashedPassword,
      role: role || 'tenant', // افتراضيًا 'tenant' إذا لم يتم تحديد دور
    });

    res.status(201).json({ message: "User registered successfully", user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// 🟣 تسجيل الدخول
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ message: "User not found" });

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) return res.status(400).json({ message: "Invalid password" });

    // تضمين دور المستخدم في الـ token
    const token = jwt.sign(
      { id: user._id, role: user.role }, // ✅ تم إضافة دور المستخدم هنا
      process.env.JWT_SECRET || "secret",
      {
        expiresIn: "7d",
      }
    );

    // إرجاع الـ token ودور المستخدم
    res.status(200).json({ token, role: user.role }); // ✅ تم إرجاع الدور هنا
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;