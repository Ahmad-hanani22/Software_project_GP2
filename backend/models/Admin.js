import mongoose from "mongoose";

const adminSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    roleTitle: {
      type: String,
      enum: ["super_admin", "support", "finance_manager", "content_manager"],
      default: "support",
    },

    permissions: {
      users: { type: Boolean, default: false }, // إدارة المستخدمين
      properties: { type: Boolean, default: false }, // إدارة العقارات
      contracts: { type: Boolean, default: false }, // العقود
      payments: { type: Boolean, default: false }, // الدفعات
      complaints: { type: Boolean, default: false }, // الشكاوى
      maintenance: { type: Boolean, default: false }, // الصيانة
      reports: { type: Boolean, default: false }, // التقارير
      systemSettings: { type: Boolean, default: false }, // إعدادات النظام
    },

    isActive: { type: Boolean, default: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // الأدمن اللي أنشأه
  },
  { timestamps: true }
);

export default mongoose.model("Admin", adminSchema);
