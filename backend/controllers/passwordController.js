import User from "../models/User.js";
import bcrypt from "bcryptjs";
import nodemailer from "nodemailer";
import dotenv from "dotenv";

dotenv.config();

// إعداد خدمة الإيميل
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    
    // 🔍 Debug Log — مهم جداً
    console.log("SMTP EMAIL_USER =", process.env.EMAIL_USER);
    console.log("SMTP EMAIL_PASS =", process.env.EMAIL_PASS ? "Loaded" : "NOT FOUND");

    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({ message: "❌ This email address is not registered." });
    }

    // توليد كود مكون من 6 أرقام
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // حفظ الكود ووقت الانتهاء (10 دقائق)
    user.resetPasswordToken = otp;
    user.resetPasswordExpires = Date.now() + 10 * 60 * 1000;

    await user.save();

    // تصميم الإيميل
    const mailOptions = {
      from: `"SHAQATI Support" <${process.env.EMAIL_USER}>`,
      to: user.email,
      subject: "Password reset code",
      html: `
        <div style="font-family: Arial, sans-serif; text-align: center; padding: 20px;">
          <h2>إعادة تعيين كلمة المرور</h2>
          <p>You have requested a password reset.</p>
          <p>Use the following code in the application:</p>
          <h1 style="color: #2E7D32; letter-spacing: 5px; background: #f0f0f0; padding: 10px; display: inline-block; border-radius: 8px;">${otp}</h1>
          <p style="color: gray;">This code is valid for 10 minutes.</p>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);

    res.status(200).json({ message: "✅ A verification code has been sent to your email address." });

  } catch (error) {
    console.error("Forgot Password Error:", error);
    res.status(500).json({ message: "Email sending failed", error: error.message });
  }
};


// 2. التحقق وتغيير كلمة المرور
export const resetPassword = async (req, res) => {
  try {
    const { email, otp, newPassword } = req.body;

    const user = await User.findOne({
      email: email,
      resetPasswordToken: otp,
      resetPasswordExpires: { $gt: Date.now() }, // التحقق من الوقت
    });

    if (!user) {
      return res.status(400).json({ message: "❌ The code is invalid or expired" });
    }

    // تشفير كلمة المرور الجديدة
    const salt = await bcrypt.genSalt(10);
    user.passwordHash = await bcrypt.hash(newPassword, salt);

    // تصفير الكود بعد الاستخدام
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;

    await user.save();

    res.status(200).json({ message: "✅ Your password has been successfully changed. You can now log in." });

  } catch (error) {
    res.status(500).json({ message: "An error occurred on the server", error: error.message });
  }
};