import express from "express";
import dotenv from "dotenv";
import mongoose from "mongoose";
import cors from "cors";
import http from "http";
import { Server } from "socket.io";

// ================================
// 🧠 Load environment variables
// ================================
dotenv.config();

// ================================
// ⚙️ Initialize Express app
// ================================
const app = express();
const PORT = process.env.PORT || 3000;

// ================================
// 🌍 CORS Configuration
// ================================
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json());

// ================================
// 🌐 HTTP + Socket.IO Server
// ================================
const server = http.createServer(app);

export const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

// ================================
// 🔌 Socket.IO Events
// ================================
io.on("connection", (socket) => {
  console.log("🔌 User connected:", socket.id);
  socket.on("join", (userId) => {
    socket.join(userId);
    console.log(`📡 User ${userId} joined room`);
  });
  socket.on("disconnect", () => {
    console.log("❌ User disconnected:", socket.id);
  });
});

app.use((req, res, next) => {
  req.io = io;
  next();
});

// ================================
// 📦 Import Routes
// ================================
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
import adminSettingsRoutes from "./routes/adminSettingsRoutes.js";
import landlordDashboardRoutes from "./routes/landlordDashboardRoutes.js";
import unitRoutes from "./routes/unitRoutes.js";
import expenseRoutes from "./routes/expenseRoutes.js";
import depositRoutes from "./routes/depositRoutes.js";
import invoiceRoutes from "./routes/invoiceRoutes.js";
import occupancyHistoryRoutes from "./routes/occupancyHistoryRoutes.js";
import propertyHistoryRoutes from "./routes/propertyHistoryRoutes.js";
import ownershipRoutes from "./routes/ownershipRoutes.js";
import buildingRoutes from "./routes/buildingRoutes.js";
import propertyTypeRoutes from "./routes/propertyTypeRoutes.js";
import { initializeDefaultSettings } from "./controllers/adminSettingsController.js";
import { seedPropertyTypes } from "./utils/seedPropertyTypes.js";

// ================================
// 🚏 Register Routes
// ================================
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
app.use("/api/admin", adminDashboardRoutes);
app.use("/api/password", passwordRoutes);
app.use("/api/upload", uploadRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/admin/settings", adminSettingsRoutes);
app.use("/api/landlord/dashboard", landlordDashboardRoutes);
app.use("/api/units", unitRoutes);
app.use("/api/expenses", expenseRoutes);
app.use("/api/deposits", depositRoutes);
app.use("/api/invoices", invoiceRoutes);
app.use("/api/occupancy-history", occupancyHistoryRoutes);
app.use("/api/property-history", propertyHistoryRoutes);
app.use("/api/ownership", ownershipRoutes);
app.use("/api/buildings", buildingRoutes);
app.use("/api/property-types", propertyTypeRoutes);

app.get("/", (req, res) => {
  res.send("🚀 SHAQATI API is running (Production Ready)");
});

// ================================
// 🚀 Start Server Logic (Modified)
// ================================

const startServer = async () => {
  try {
    console.log("⏳ Connecting to MongoDB...");
    // 1. Connect to MongoDB First
    await mongoose.connect(process.env.MONGO_URI);
    console.log("✅ Connected to MongoDB Atlas");

    // 2. Run Seeders
    try {
      await initializeDefaultSettings();
      await seedPropertyTypes();
      console.log("✅ Seeders finished");
    } catch (seedError) {
      console.error("⚠️ Seeders warning:", seedError.message);
    }

    // 3. Start Listening ONLY after DB is ready
    server.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`🌍 Public URL: ${process.env.APP_URL || `http://localhost:${PORT}`}`);
    });

  } catch (error) {
    console.error("❌ Failed to connect to MongoDB:", error.message);
    // Exit process so you know it failed
    process.exit(1);
  }
};

// Handle MongoDB connection errors after initial connection
mongoose.connection.on("error", (err) => {
  console.error("❌ MongoDB connection error:", err);
});

mongoose.connection.on("disconnected", () => {
  console.warn("⚠️ MongoDB disconnected");
});

startServer();