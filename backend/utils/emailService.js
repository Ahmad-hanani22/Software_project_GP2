import nodemailer from "nodemailer";
import dotenv from "dotenv";

dotenv.config();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
  tls: {
    rejectUnauthorized: false,
  },
});

/* ============================
   Verification Email
============================ */
export const sendVerificationEmail = async (toEmail, token) => {
  const verifyUrl = `${process.env.APP_URL}/api/auth/verify/${token}`;

  const mailOptions = {
    from: `"SHAQATI Team" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: "Activate your SHAQATI account",
    html: `
      <div style="font-family: Arial; padding: 20px; direction: rtl;">
        <h2 style="color:#2E7D32">مرحباً بك في شقتي 👋</h2>
        <p>اضغط على الزر التالي لتفعيل حسابك:</p>
        <div style="margin: 30px 0; text-align:center">
          <a href="${verifyUrl}"
             style="background:#2E7D32;color:white;padding:12px 24px;
                    border-radius:6px;text-decoration:none;font-size:16px">
            تفعيل الحساب
          </a>
        </div>
        <p style="font-size:12px;color:gray">
          إذا لم تقم بإنشاء حساب، تجاهل هذا الإيميل.
        </p>
      </div>
    `,
  };

  await transporter.sendMail(mailOptions);
};

/* ============================
   Login Notification
============================ */
export const sendLoginNotification = async (toEmail, userName) => {
  await transporter.sendMail({
    from: `"SHAQATI Security" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: "New login detected",
    html: `
      <p>Hello ${userName},</p>
      <p>You logged in at ${new Date().toLocaleString()}</p>
    `,
  });
};

export default transporter;
