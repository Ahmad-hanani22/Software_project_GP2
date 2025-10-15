import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    message: String,

    // صنّف الإشعار (وسعنا القائمة)
    type: {
      type: String,
      enum: [
        "payment",
        "contract",
        "maintenance",
        "complaint",
        "property",
        "chat",
        "system",
      ],
      default: "system",
    },

    // حقول اختيارية مفيدة للربط والواجهة
    actorId: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // من عمل الحدث
    entityType: { type: String }, // "maintenance" | "payment" | ...
    entityId: { type: mongoose.Schema.Types.ObjectId }, // ID للعنصر
    link: String, // رابط تفصيلي بالواجهة (اختياري)

    isRead: { type: Boolean, default: false },
  },
  { timestamps: true }
);

export default mongoose.model("Notification", notificationSchema);
