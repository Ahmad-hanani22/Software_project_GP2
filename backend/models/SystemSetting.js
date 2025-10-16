// models/SystemSetting.js
import mongoose from "mongoose";

const systemSettingSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      required: true,
      unique: true, // كل إعداد يجب أن يكون له مفتاح فريد
    },
    value: {
      type: mongoose.Schema.Types.Mixed, // يمكن أن يكون من أي نوع (String, Number, Boolean)
      required: true,
    },
    type: {
      type: String,
      enum: ["text", "boolean", "dropdown", "number"], // أنواع الإعدادات المتاحة
      required: true,
    },
    label: {
      type: String, // الاسم المعروض في الواجهة الأمامية
      required: true,
    },
    options: {
      type: [String], // خيارات لقوائم الـ dropdown
      default: undefined, // لا يتم تخزينه إذا كان فارغًا
    },
    category: {
      type: String, // لتجميع الإعدادات في فئات في الواجهة الأمامية
      default: "General",
    },
    description: {
      type: String, // وصف موجز للإعداد
      default: "",
    },
  },
  { timestamps: true }
);

const SystemSetting = mongoose.model("SystemSetting", systemSettingSchema);
export default SystemSetting;
