import mongoose from "mongoose";

const contractTemplateSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      trim: true,
    },

    // 📋 بيانات القالب الافتراضية
    defaultRentAmount: {
      type: Number,
      default: 0,
    },
    defaultDepositAmount: {
      type: Number,
      // عادة يساوي شهر إيجار أو أكثر
    },
    defaultPaymentCycle: {
      type: String,
      enum: ["monthly", "quarterly", "yearly"],
      default: "monthly",
    },
    defaultContractDuration: {
      // مدة العقد بالشهور (افتراضياً)
      type: Number,
      default: 12, // 12 شهر
    },

    // 📄 محتوى القالب (الشروط والأحكام)
    templateContent: {
      type: String,
      // نص العقد الكامل (HTML أو Markdown)
      default: "",
    },

    // ✅ الشروط والأحكام الافتراضية
    terms: [
      {
        title: String, // عنوان الشرط
        description: String, // نص الشرط
      },
    ],

    // 🔧 خيارات القالب
    isActive: {
      type: Boolean,
      default: true,
    },
    isDefault: {
      type: Boolean,
      default: false, // القالب الافتراضي
    },

    // 👤 منشئ القالب
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // 📊 إحصائيات استخدام القالب
    usageCount: {
      type: Number,
      default: 0, // عدد مرات استخدام القالب
    },
    lastUsedAt: Date, // آخر مرة استُخدم فيها القالب
  },
  { timestamps: true }
);

// ✅ تأكد من وجود قالب افتراضي واحد فقط
contractTemplateSchema.pre("save", async function (next) {
  if (this.isDefault && !this.isNew) {
    // إذا كان هذا القالب هو الافتراضي، قم بإلغاء الافتراضي من القوالب الأخرى
    const ContractTemplateModel = mongoose.model("ContractTemplate");
    await ContractTemplateModel.updateMany(
      { _id: { $ne: this._id }, isDefault: true },
      { $set: { isDefault: false } }
    );
  }
  next();
});

export default mongoose.model("ContractTemplate", contractTemplateSchema);
