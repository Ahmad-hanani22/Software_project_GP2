import mongoose from "mongoose";

const ownershipSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      required: true,
    },
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    percentage: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
    },
    // معلومات إضافية
    isPrimary: {
      type: Boolean,
      default: false, // المالك الرئيسي
    },
    notes: {
      type: String,
    },
  },
  { timestamps: true }
);

// Index - مالك واحد يمكن أن يكون له نسبة واحدة فقط في عقار
ownershipSchema.index({ propertyId: 1, ownerId: 1 }, { unique: true });

// Validation: مجموع النسب يجب أن لا يتجاوز 100%
ownershipSchema.pre("save", async function (next) {
  if (this.isNew || this.isModified("percentage")) {
    try {
      const OwnershipModel = mongoose.model("Ownership");
      const filter = { propertyId: this.propertyId };
      
      // إذا كان التحديث، استثني السجل الحالي
      if (!this.isNew) {
        filter._id = { $ne: this._id };
      }

      const totalOwnership = await OwnershipModel.aggregate([
        { $match: filter },
        { $group: { _id: null, total: { $sum: "$percentage" } } },
      ]);

      const currentTotal = totalOwnership[0]?.total || 0;
      const newTotal = currentTotal + this.percentage;

      if (newTotal > 100) {
        return next(new Error("Total ownership percentage cannot exceed 100%"));
      }
    } catch (error) {
      // في حالة عدم وجود النموذج بعد (أثناء التهيئة)، تجاهل الخطأ
      if (error.name !== 'MissingSchemaError') {
        return next(error);
      }
    }
  }
  next();
});

const Ownership = mongoose.model("Ownership", ownershipSchema);

export default Ownership;

