import mongoose from "mongoose";

// 🧠 نموذج جمع البيانات السلوكية للمستخدم
const userBehaviorSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    
    // 📊 بيانات الزيارات والتصفح
    propertyViews: [
      {
        propertyId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Property",
        },
        viewCount: { type: Number, default: 1 },
        totalViewDuration: { type: Number, default: 0 }, // بالثواني
        lastViewedAt: { type: Date, default: Date.now },
        firstViewedAt: { type: Date, default: Date.now },
      },
    ],
    
    // ⭐ العقارات المحفوظة
    favoriteProperties: [
      {
        propertyId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Property",
        },
        addedAt: { type: Date, default: Date.now },
      },
    ],
    
    // 🔍 عمليات البحث
    searchHistory: [
      {
        query: String,
        filters: {
          city: String,
          type: String,
          operation: String,
          minPrice: Number,
          maxPrice: Number,
          bedrooms: Number,
        },
        resultsCount: Number,
        searchedAt: { type: Date, default: Date.now },
      },
    ],
    
    // 💰 نطاق السعر المفضل
    priceFocus: {
      min: Number,
      max: Number,
      currency: { type: String, default: "USD" },
      lastUpdated: Date,
    },
    
    // 📍 المدينة/المنطقة المفضلة
    preferredLocations: [
      {
        city: String,
        frequency: { type: Number, default: 1 },
        lastSearched: Date,
      },
    ],
    
    // 🏠 نوع العقار المفضل
    preferredPropertyTypes: [
      {
        type: String,
        frequency: { type: Number, default: 1 },
        lastSearched: Date,
      },
    ],
    
    // 🛏️ عدد الغرف المفضل
    preferredBedrooms: {
      min: Number,
      max: Number,
      mostCommon: Number,
    },
    
    // 📅 تاريخ العقود السابقة
    contractHistory: [
      {
        contractId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Contract",
        },
        propertyId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Property",
        },
        startDate: Date,
        endDate: Date,
        rentAmount: Number,
      },
    ],
    
    // 💳 المدفوعات والمصاريف
    paymentHistory: [
      {
        paymentId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Payment",
        },
        amount: Number,
        date: Date,
      },
    ],
    
    // 🔧 طلبات الصيانة
    maintenanceRequests: [
      {
        requestId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "MaintenanceRequest",
        },
        propertyId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Property",
        },
        status: String,
        createdAt: Date,
      },
    ],
    
    // ⭐ التقييمات
    reviews: [
      {
        reviewId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Review",
        },
        propertyId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Property",
        },
        rating: Number,
        createdAt: Date,
      },
    ],
    
    // ⏱️ سرعة استجابة المالك (للعقارات المستأجرة)
    landlordResponseTimes: [
      {
        propertyId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Property",
        },
        averageResponseTime: Number, // بالدقائق
        lastInteraction: Date,
      },
    ],
    
    // 📊 أنماط السلوك
    behaviorPatterns: {
      isComparer: { type: Boolean, default: false }, // يقارن بين عقارات
      isHesitant: { type: Boolean, default: false }, // متردد
      isReadyToRent: { type: Boolean, default: false }, // جاهز للاستئجار
      userType: {
        type: String,
        enum: ["student", "family", "employee", "investor", "unknown"],
        default: "unknown",
      },
      budgetLevel: {
        type: String,
        enum: ["low", "medium", "high", "unknown"],
        default: "unknown",
      },
    },
    
    // 📈 إحصائيات عامة
    stats: {
      totalViews: { type: Number, default: 0 },
      totalSearchCount: { type: Number, default: 0 },
      averageViewDuration: { type: Number, default: 0 },
      favoriteCount: { type: Number, default: 0 },
    },
  },
  { timestamps: true }
);

// Indexes
userBehaviorSchema.index({ userId: 1 });
userBehaviorSchema.index({ "propertyViews.propertyId": 1 });
userBehaviorSchema.index({ "favoriteProperties.propertyId": 1 });

export default mongoose.model("UserBehavior", userBehaviorSchema);
