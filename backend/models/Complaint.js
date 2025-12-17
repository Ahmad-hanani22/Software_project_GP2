import mongoose from "mongoose";

const complaintSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    againstUserId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    // نوع المشتكي (مثلاً: مستأجر / مالك) - احتفظنا به للتوافق
    type: { type: String, enum: ["tenant", "landlord"] },

    // نص الشكوى
    description: { type: String, required: true },

    // تصنيف الشكوى (مالي / صيانة / سلوك)
    category: {
      type: String,
      enum: ["financial", "maintenance", "behavior"],
      required: true,
    },

    // حالة الشكوى ضمن دورة الحياة
    status: {
      type: String,
      enum: ["open", "in_progress", "resolved", "closed"],
      default: "open",
    },

    // قرار الأدمن النهائي (نص احترافي يوضح النتيجة)
    adminDecision: {
      type: String,
    },

    // مرفقات (صور / ملفات) URLs
    attachments: [
      {
        url: String,
        name: String,
        uploadedAt: { type: Date, default: Date.now },
      },
    ],
  },
  { timestamps: true }
);

export default mongoose.model("Complaint", complaintSchema);
