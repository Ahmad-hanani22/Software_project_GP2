import nodemailer from "nodemailer";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, "../.env") });

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  tls: {
    rejectUnauthorized: false 
  }
});


export const sendLoginNotification = async (toEmail, userName) => {
  console.log(`📨 Preparing to send login email to: ${toEmail}`);

  const mailOptions = {
    from: `"SHAQATI Security" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: "🔐 New login - SHAQATI",
    html: `
      <div style="direction: rtl; font-family: Arial, sans-serif; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #2E7D32;">Welcome ${userName}</h2>
        <p>You have successfully logged into your account.</p>
        <p><strong>Time of entry:</strong> ${new Date().toLocaleString()}</p>
        <hr>
        <p style="color: gray; font-size: 12px;">SHAQATI Team/p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Login Email SENT to ${toEmail}`);
  } catch (error) {
    console.error(`❌ Login Email FAILED: ${error.message}`);
  }
};


export const sendPasswordResetCode = async (toEmail, otp) => {
  try {
    await transporter.sendMail({
      from: `"SHAQATI Support" <${process.env.EMAIL_USER}>`,
      to: toEmail,
      subject: "Verification code - Password recovery",
      html: `
        <div style="text-align: center; padding: 20px; font-family: Arial;">
          <h2>Your verification code</h2>
          <h1 style="color: #2E7D32; background: #f0f0f0; padding: 10px; display: inline-block; letter-spacing: 5px;">${otp}</h1>
          <p>Use this code to reset your password.</p>
        </div>
      `,
    });
    console.log(`✅ OTP Email SENT to ${toEmail}`);
    return true;
  } catch (error) {
    console.error(`❌ OTP Email FAILED: ${error.message}`);
    return false;
  }
};

export const sendVerificationEmail = async (toEmail, token) => {
  
  const serverIp = "192.168.88.3"; 
  const verifyUrl = `http://${serverIp}:3000/api/auth/verify/${token}`;

  console.log(`🚀 Preparing Verification Email for: ${toEmail}`);
  
  const mailOptions = {
    from: `"SHAQATI Team" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: "⚡ Activate your account in SHAQATI.",
    html: `
      <div style="direction: rtl; text-align: right; font-family: Arial; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
        <h2 style="color: #2E7D32;">Welcome to SHAQATI!</h2>
        <p>Thank you for registering with us. Please click the button below to activate your account:</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="${verifyUrl}" style="background-color: #2E7D32; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; font-weight: bold; font-size: 16px;">Activate your account now</a>
        </div>
        <p style="color: #555;">Alternatively, you can copy and paste the following link into your browser:</p>
        <p style="background: #f9f9f9; padding: 10px; word-break: break-all; font-size: 12px;">${verifyUrl}</p>
        <hr>
        <p style="color: gray; font-size: 12px;">If you have not registered, please ignore this message.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Verification Email SENT to ${toEmail}`);
  } catch (error) {
    console.error(`❌ Verification Email FAILED: ${error.message}`);
  }
};

export default transporter;