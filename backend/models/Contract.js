import mongoose from "mongoose";

const contractSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      // required: false, // جعلناها optional للتوافق مع الترقية
    },
    unitId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Unit",
      // required: true, // يمكن تفعيلها لاحقاً
    },
    tenantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    landlordId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    startDate: Date,
    endDate: Date,
    rentAmount: Number,
    depositAmount: {
      type: Number,
      // مبلغ الوديعة المتفق عليه في العقد (عادة يساوي شهر إيجار أو أكثر)
    },
    paymentCycle: {
      type: String,
      enum: ["monthly", "quarterly", "yearly"],
      default: "monthly",
    },

    // 👇 حالات العقد المتقدمة
    status: {
      type: String,
      enum: [
        "draft", // مسودة
        "pending", // قيد الموافقة
        "active", // فعال
        "expiring_soon", // يوشك على الانتهاء
        "expired", // منتهي
        "terminated", // منهي
        "rented", // متوافق مع الشيفرة القديمة
        "rejected", // لرفض العقد
      ],
      default: "pending",
    },

    // 📄 رابط ملف الـ PDF الأساسي للعقد
    pdfUrl: String,

    // 📎 مرفقات إضافية (مثلاً ملاحق العقد)
    attachments: [
      {
        url: String,
        name: String,
        uploadedAt: { type: Date, default: Date.now },
      },
    ],

    // ✍️ توقيع إلكتروني للطرفين
    signatures: {
      landlord: {
        signed: { type: Boolean, default: false },
        signedAt: Date,
      },
      tenant: {
        signed: { type: Boolean, default: false },
        signedAt: Date,
      },
    },

    // 🔁 بيانات التجديد
    renewalCount: { type: Number, default: 0 },
    lastRenewedAt: Date,

    // 🧨 طلب إنهاء
    termination: {
      requestedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
      reason: String,
      requestedAt: Date,
      approvedAt: Date,
    },
  },
  { timestamps: true }
);

export default mongoose.model("Contract", contractSchema);
