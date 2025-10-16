import express from "express";
import dotenv from "dotenv";
import mongoose from "mongoose";
import cors from "cors";
import http from "http";
import { Server } from "socket.io";

// 🧠 تحميل متغيرات البيئة
dotenv.config();
console.log("MONGO_URI is:", process.env.MONGO_URI);

// ⚙️ إعداد تطبيق Express
const app = express();

// ✅ السماح بالاتصال من Flutter Web
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());

// 🗄️ الاتصال بقاعدة البيانات MongoDB
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("✅ Connected to MongoDB Atlas"))
  .catch((err) => console.error("❌ Error connecting to MongoDB:", err));

// =====================================================
// ✅ Socket.IO Configuration
// =====================================================
const server = http.createServer(app);
export const io = new Server(server, {
  cors: { origin: "*" },
});

io.on("connection", (socket) => {
  console.log("🔌 User connected:", socket.id);

  socket.on("join", (userId) => {
    socket.join(userId);
    console.log(`📡 User ${userId} joined their room`);
  });

  socket.on("disconnect", () => {
    console.log("❌ User disconnected:", socket.id);
  });
});

// =====================================================
// ✅ استيراد الراوتات
// =====================================================
import userRoutes from "./routes/userRoutes.js";
import propertyRoutes from "./routes/propertyRoutes.js";
import paymentRoutes from "./routes/paymentRoutes.js";
import contractRoutes from "./routes/contractRoutes.js";
import maintenanceRoutes from "./routes/maintenanceRoutes.js";
import complaintRoutes from "./routes/complaintRoutes.js";
import notificationRoutes from "./routes/notificationRoutes.js";
import chatRoutes from "./routes/chatRoutes.js";
import adminRoutes from "./routes/adminRoutes.js";
import reviewRoutes from "./routes/reviewRoutes.js";
import testRoutes from "./routes/testRoutes.js";
import notificationDashboardRoutes from "./routes/notificationDashboardRoutes.js";
import adminDashboardRoutes from "./routes/adminDashboardRoutes.js";
import passwordRoutes from "./routes/passwordRoutes.js";
import uploadRoutes from "./routes/uploadRoutes.js";
import authRoutes from "./routes/authRoutes.js";
// ✅ جديد: استيراد مسارات إعدادات النظام ودالة التهيئة
import adminSettingsRoutes from "./routes/adminSettingsRoutes.js";
import { initializeDefaultSettings } from "./controllers/adminSettingsController.js";

// =====================================================
// ✅ ربط الراوتات
// =====================================================
app.use("/api/users", userRoutes);
app.use("/api/properties", propertyRoutes);
app.use("/api/contracts", contractRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/maintenance", maintenanceRoutes);
app.use("/api/complaints", complaintRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/chats", chatRoutes);
app.use("/api/admins", adminRoutes);
app.use("/api/reviews", reviewRoutes);
app.use("/api/test", testRoutes);
app.use("/api/notification-dashboard", notificationDashboardRoutes);
app.use("/api/admin", adminDashboardRoutes); // ✅ Dashboard route
app.use("/api/password", passwordRoutes);
app.use("/api/upload", uploadRoutes);
app.use("/api/auth", authRoutes);
// ✅ جديد: ربط مسارات إعدادات النظام
app.use("/api/admin/settings", adminSettingsRoutes);

// =====================================================
// ✅ اختبار بسيط
// =====================================================
app.get("/", (req, res) => {
  res.send("🚀 API is running with real-time notifications!");
});

// =====================================================
// 🚀 تشغيل السيرفر
// =====================================================
const PORT = process.env.PORT || 3000;
server.listen(PORT, async () => {
  console.log(`🚀 Server running on port ${PORT} (with Socket.IO enabled)`);
  // ✅ جديد: استدعاء دالة تهيئة الإعدادات الافتراضية عند بدء التشغيل
  await initializeDefaultSettings();
});
