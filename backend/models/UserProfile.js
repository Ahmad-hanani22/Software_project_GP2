import mongoose from "mongoose";

// 🧠 نموذج التوصيف الذكي للمستخدم
const userProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
      index: true,
    },
    
    // 💰 نطاق الميزانية
    budgetRange: {
      min: Number,
      max: Number,
      preferred: Number, // السعر المفضل
      currency: { type: String, default: "USD" },
      confidence: { type: Number, default: 0 }, // 0-100
    },
    
    // 📍 المواقع المفضلة
    preferredLocations: [
      {
        city: String,
        area: String,
        priority: { type: Number, default: 1 }, // 1-10
        lastSearched: Date,
      },
    ],
    
    // 🏠 أنواع العقارات المفضلة
    preferredPropertyTypes: [
      {
        type: String,
        priority: { type: Number, default: 1 },
        lastSearched: Date,
      },
    ],
    
    // ⏱️ مدة الإيجار المفضلة
    rentalDurationPreference: {
      min: Number, // بالأشهر
      max: Number,
      preferred: Number,
    },
    
    // 💵 الحساسية للسعر
    priceSensitivity: {
      type: String,
      enum: ["low", "medium", "high"], // منخفضة = يهتم بالجودة أكثر
      default: "medium",
    },
    
    // 🎯 الاهتمام بالجودة مقابل السعر
    qualityVsPrice: {
      type: String,
      enum: ["quality", "balanced", "price"], // الجودة أولاً / متوازن / السعر أولاً
      default: "balanced",
    },
    
    // 👤 نوع المستخدم
    userType: {
      type: String,
      enum: ["student", "family", "employee", "investor", "unknown"],
      default: "unknown",
    },
    
    // 📊 Trust Preferences
    trustPreferences: {
      minTrustScore: { type: Number, default: 0 }, // 0-100
      preferVerified: { type: Boolean, default: false },
      preferHighRated: { type: Boolean, default: true },
    },
    
    // 🛏️ تفضيلات الغرف
    bedroomPreferences: {
      min: Number,
      max: Number,
      preferred: Number,
    },
    
    // 🚿 تفضيلات الحمامات
    bathroomPreferences: {
      min: Number,
      max: Number,
    },
    
    // 📐 تفضيلات المساحة
    areaPreferences: {
      min: Number, // بالمتر المربع
      max: Number,
    },
    
    // 🎨 تفضيلات إضافية
    amenities: [String], // قائمة المرافق المفضلة
    
    // 📅 آخر تحديث
    lastUpdated: { type: Date, default: Date.now },
    
    // 🔄 تاريخ التحديثات
    updateHistory: [
      {
        field: String,
        oldValue: mongoose.Schema.Types.Mixed,
        newValue: mongoose.Schema.Types.Mixed,
        updatedAt: { type: Date, default: Date.now },
      },
    ],
  },
  { timestamps: true }
);

// Indexes
userProfileSchema.index({ userId: 1 });
userProfileSchema.index({ "preferredLocations.city": 1 });

export default mongoose.model("UserProfile", userProfileSchema);
