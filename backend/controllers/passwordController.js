// controllers/passwordController.js
import crypto from "crypto";
import bcrypt from "bcryptjs";
import User from "../models/User.js";
import nodemailer from "nodemailer";
import { sendNotification } from "../utils/sendNotification.js";


export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: "❌ User not found" });

    // توليد توكن مؤقت
    const token = crypto.randomBytes(20).toString("hex");
    user.resetPasswordToken = token;
    user.resetPasswordExpires = Date.now() + 15 * 60 * 1000; // 15 دقيقة
    await user.save();

    // إعداد إرسال الإيميل (Gmail مثلاً)
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });

    const resetUrl = `http://localhost:3000/api/users/reset-password/${token}`;

    const mailOptions = {
      from: `"Real Estate App" <${process.env.EMAIL_USER}>`,
      to: user.email,
      subject: "Reset Your Password",
      html: `
        <p>مرحبًا ${user.name},</p>
        <p>لقد طلبت إعادة تعيين كلمة المرور الخاصة بك.</p>
        <p>اضغط على الرابط التالي لإعادة تعيينها (صالح لـ 15 دقيقة):</p>
        <a href="${resetUrl}">${resetUrl}</a>
      `,
    };

    await transporter.sendMail(mailOptions);

    res.status(200).json({
      message: "✅ Password reset link sent to your email",
      token,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error sending reset email", error: error.message });
  }
};


export const resetPassword = async (req, res) => {
  try {
    const { token } = req.params;
    const { newPassword } = req.body;

    const user = await User.findOne({
      resetPasswordToken: token,
      resetPasswordExpires: { $gt: Date.now() }, // تأكد أنه لم ينتهِ
    });

    if (!user)
      return res.status(400).json({ message: "❌ Invalid or expired token" });

    const hashed = await bcrypt.hash(newPassword, 10);

    user.passwordHash = hashed;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;
    await user.save();

    
    await sendNotification({
      userId: user._id,
      message: "✅ تم تغيير كلمة المرور الخاصة بك بنجاح",
      type: "security",
      actorId: user._id,
      entityType: "user",
      entityId: user._id,
      link: "/profile",
    });

    res
      .status(200)
      .json({ message: "✅ Password has been reset successfully" });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error resetting password", error: error.message });
  }
};
