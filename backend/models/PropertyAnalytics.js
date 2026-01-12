import mongoose from "mongoose";

// 🧠 نموذج تحليلات العقار
const propertyAnalyticsSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      required: true,
      unique: true,
      index: true,
    },
    
    // 📊 إحصائيات الزيارات
    viewStats: {
      totalViews: { type: Number, default: 0 },
      uniqueViews: { type: Number, default: 0 },
      averageViewDuration: { type: Number, default: 0 }, // بالثواني
      lastViewedAt: Date,
    },
    
    // ⭐ إحصائيات المحفوظات
    favoriteStats: {
      totalFavorites: { type: Number, default: 0 },
      uniqueUsers: { type: Number, default: 0 },
    },
    
    // 💰 تحليل السعر
    priceAnalysis: {
      currentPrice: Number,
      averageMarketPrice: Number, // متوسط سعر السوق في المنطقة
      priceVsMarket: { type: Number, default: 0 }, // الفرق من المتوسط (%)
      isOverpriced: { type: Boolean, default: false },
      isUnderpriced: { type: Boolean, default: false },
      priceHistory: [
        {
          price: Number,
          date: Date,
        },
      ],
    },
    
    // ⭐ Trust Score
    trustScore: {
      score: { type: Number, default: 50 }, // 0-100
      factors: {
        ownerRating: { type: Number, default: 0 }, // تقييم المالك
        complaintCount: { type: Number, default: 0 },
        maintenanceCount: { type: Number, default: 0 },
        averageResponseTime: { type: Number, default: 0 }, // بالدقائق
        reviewRating: { type: Number, default: 0 }, // متوسط التقييمات
        verified: { type: Boolean, default: false },
        contractStability: { type: Number, default: 0 }, // استقرار العقود (0-100)
      },
      lastCalculated: Date,
    },
    
    // 🔧 تحليل الصيانة
    maintenanceAnalysis: {
      totalRequests: { type: Number, default: 0 },
      resolvedCount: { type: Number, default: 0 },
      pendingCount: { type: Number, default: 0 },
      averageResolutionTime: { type: Number, default: 0 }, // بالأيام
      maintenanceLevel: {
        type: String,
        enum: ["low", "medium", "high"],
        default: "low",
      },
      recurringIssues: [String], // المشاكل المتكررة
    },
    
    // 📅 تحليل الإشغال
    occupancyAnalysis: {
      totalOccupancyDays: { type: Number, default: 0 },
      averageOccupancyDuration: { type: Number, default: 0 }, // بالأيام
      vacancyRate: { type: Number, default: 0 }, // نسبة الشغور (%)
      lastOccupiedAt: Date,
      lastVacantAt: Date,
      occupancyHistory: [
        {
          from: Date,
          to: Date,
          duration: Number, // بالأيام
        },
      ],
    },
    
    // 📈 الطلب الحالي
    demandLevel: {
      type: String,
      enum: ["low", "medium", "high", "very_high"],
      default: "medium",
      factors: {
        viewCount: Number,
        favoriteCount: Number,
        inquiryCount: Number,
        searchFrequency: Number,
      },
      lastCalculated: Date,
    },
    
    // 💵 تحليل التكلفة
    costAnalysis: {
      monthlyOperatingCost: { type: Number, default: 0 },
      averageExpenses: { type: Number, default: 0 },
      expenseBreakdown: {
        maintenance: Number,
        tax: Number,
        utility: Number,
        management: Number,
        insurance: Number,
        other: Number,
      },
    },
    
    // 🎯 Recommendation Score
    recommendationScore: {
      score: { type: Number, default: 0 }, // 0-100
      factors: {
        priceValue: Number, // قيمة السعر مقابل السوق
        trustScore: Number,
        maintenanceLevel: Number,
        demandLevel: Number,
        locationScore: Number,
      },
      lastCalculated: Date,
    },
    
    // 📊 مقارنة مع عقارات مشابهة
    marketComparison: {
      similarPropertiesCount: { type: Number, default: 0 },
      averagePrice: Number,
      averageRating: Number,
      position: {
        type: String,
        enum: ["below_average", "average", "above_average"],
        default: "average",
      },
    },
    
    // 🔔 تنبيهات
    alerts: [
      {
        type: {
          type: String,
          enum: [
            "price_drop",
            "high_demand",
            "low_trust",
            "maintenance_issue",
            "new_similar",
          ],
        },
        message: String,
        createdAt: { type: Date, default: Date.now },
        isRead: { type: Boolean, default: false },
      },
    ],
    
    // 📅 آخر تحديث
    lastUpdated: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

// Indexes
propertyAnalyticsSchema.index({ propertyId: 1 });
propertyAnalyticsSchema.index({ "trustScore.score": -1 });
propertyAnalyticsSchema.index({ "recommendationScore.score": -1 });
propertyAnalyticsSchema.index({ "demandLevel": 1 });

export default mongoose.model("PropertyAnalytics", propertyAnalyticsSchema);
