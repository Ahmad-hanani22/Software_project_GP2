import UserBehavior from "../models/UserBehavior.js";
import UserProfile from "../models/UserProfile.js";
import PropertyAnalytics from "../models/PropertyAnalytics.js";
import Property from "../models/Property.js";
import Contract from "../models/Contract.js";
import Review from "../models/Review.js";
import MaintenanceRequest from "../models/MaintenanceRequest.js";
import Payment from "../models/Payment.js";
import OccupancyHistory from "../models/OccupancyHistory.js";
import Expense from "../models/Expense.js";
import User from "../models/User.js";

// ========================================================
// 🧠 1️⃣ جمع البيانات (Data Collection)
// ========================================================

// تسجيل زيارة عقار
export const trackPropertyView = async (req, res) => {
  try {
    const { userId, propertyId, viewDuration } = req.body; // viewDuration بالثواني

    let behavior = await UserBehavior.findOne({ userId });
    if (!behavior) {
      behavior = new UserBehavior({ userId });
    }

    // تحديث أو إضافة زيارة
    const existingView = behavior.propertyViews.find(
      (v) => v.propertyId.toString() === propertyId
    );

    if (existingView) {
      existingView.viewCount += 1;
      existingView.totalViewDuration += viewDuration || 0;
      existingView.lastViewedAt = new Date();
    } else {
      behavior.propertyViews.push({
        propertyId,
        viewCount: 1,
        totalViewDuration: viewDuration || 0,
        lastViewedAt: new Date(),
        firstViewedAt: new Date(),
      });
    }

    behavior.stats.totalViews += 1;
    await behavior.save();

    // تحديث PropertyAnalytics
    let analytics = await PropertyAnalytics.findOne({ propertyId });
    if (!analytics) {
      analytics = new PropertyAnalytics({ propertyId });
    }
    analytics.viewStats.totalViews += 1;
    analytics.viewStats.lastViewedAt = new Date();
    if (viewDuration) {
      const currentAvg = analytics.viewStats.averageViewDuration;
      const totalViews = analytics.viewStats.totalViews;
      analytics.viewStats.averageViewDuration =
        (currentAvg * (totalViews - 1) + viewDuration) / totalViews;
    }
    await analytics.save();

    res.status(200).json({ success: true, message: "View tracked" });
  } catch (error) {
    res.status(500).json({ message: "Error tracking view", error: error.message });
  }
};

// إضافة/إزالة من المفضلة
export const toggleFavorite = async (req, res) => {
  try {
    const { userId, propertyId } = req.body;

    let behavior = await UserBehavior.findOne({ userId });
    if (!behavior) {
      behavior = new UserBehavior({ userId });
    }

    const existingIndex = behavior.favoriteProperties.findIndex(
      (f) => f.propertyId.toString() === propertyId
    );

    if (existingIndex >= 0) {
      behavior.favoriteProperties.splice(existingIndex, 1);
      behavior.stats.favoriteCount = Math.max(0, behavior.stats.favoriteCount - 1);
    } else {
      behavior.favoriteProperties.push({
        propertyId,
        addedAt: new Date(),
      });
      behavior.stats.favoriteCount += 1;
    }

    await behavior.save();

    // تحديث PropertyAnalytics
    let analytics = await PropertyAnalytics.findOne({ propertyId });
    if (!analytics) {
      analytics = new PropertyAnalytics({ propertyId });
    }
    analytics.favoriteStats.totalFavorites = behavior.stats.favoriteCount;
    await analytics.save();

    res.status(200).json({
      success: true,
      isFavorite: existingIndex < 0,
      message: existingIndex >= 0 ? "Removed from favorites" : "Added to favorites",
    });
  } catch (error) {
    res.status(500).json({ message: "Error toggling favorite", error: error.message });
  }
};

// تسجيل عملية بحث
export const trackSearch = async (req, res) => {
  try {
    const { userId, query, filters, resultsCount } = req.body;

    let behavior = await UserBehavior.findOne({ userId });
    if (!behavior) {
      behavior = new UserBehavior({ userId });
    }

    behavior.searchHistory.push({
      query,
      filters: filters || {},
      resultsCount: resultsCount || 0,
      searchedAt: new Date(),
    });

    behavior.stats.totalSearchCount += 1;

    // تحديث التفضيلات بناءً على البحث
    if (filters) {
      if (filters.city) {
        const cityIndex = behavior.preferredLocations.findIndex(
          (l) => l.city === filters.city
        );
        if (cityIndex >= 0) {
          behavior.preferredLocations[cityIndex].frequency += 1;
          behavior.preferredLocations[cityIndex].lastSearched = new Date();
        } else {
          behavior.preferredLocations.push({
            city: filters.city,
            frequency: 1,
            lastSearched: new Date(),
          });
        }
      }

      if (filters.type) {
        const typeIndex = behavior.preferredPropertyTypes.findIndex(
          (t) => t.type === filters.type
        );
        if (typeIndex >= 0) {
          behavior.preferredPropertyTypes[typeIndex].frequency += 1;
          behavior.preferredPropertyTypes[typeIndex].lastSearched = new Date();
        } else {
          behavior.preferredPropertyTypes.push({
            type: filters.type,
            frequency: 1,
            lastSearched: new Date(),
          });
        }
      }

      if (filters.minPrice || filters.maxPrice) {
        behavior.priceFocus = {
          min: filters.minPrice || behavior.priceFocus?.min || 0,
          max: filters.maxPrice || behavior.priceFocus?.max || 1000000,
          currency: filters.currency || "USD",
          lastUpdated: new Date(),
        };
      }
    }

    await behavior.save();
    res.status(200).json({ success: true, message: "Search tracked" });
  } catch (error) {
    res.status(500).json({ message: "Error tracking search", error: error.message });
  }
};

// ========================================================
// 🧠 2️⃣ تحليل سلوك المستخدم (User Behavior Analysis)
// ========================================================

// تحليل نمط المستخدم
export const analyzeUserBehavior = async (req, res) => {
  try {
    const { userId } = req.params;

    let behavior = await UserBehavior.findOne({ userId });
    if (!behavior) {
      return res.status(200).json({
        success: true,
        analysis: {
          userType: "unknown",
          isComparer: false,
          isHesitant: false,
          isReadyToRent: false,
          budgetLevel: "unknown",
        },
      });
    }

    // تحليل نوع المستخدم
    let userType = "unknown";
    const contracts = await Contract.find({ tenantId: userId });
    const avgRent = contracts.length > 0
      ? contracts.reduce((sum, c) => sum + (c.rentAmount || 0), 0) / contracts.length
      : 0;

    if (avgRent < 300) userType = "student";
    else if (avgRent >= 300 && avgRent < 600) userType = "employee";
    else if (avgRent >= 600) userType = "family";
    else if (behavior.behaviorPatterns.userType === "investor") userType = "investor";

    // تحليل الميزانية
    let budgetLevel = "unknown";
    const priceFocus = behavior.priceFocus;
    if (priceFocus) {
      const avgPrice = (priceFocus.min + priceFocus.max) / 2;
      if (avgPrice < 300) budgetLevel = "low";
      else if (avgPrice < 600) budgetLevel = "medium";
      else budgetLevel = "high";
    }

    // تحليل السلوك
    const isComparer = behavior.propertyViews.length > 5; // شاهد أكثر من 5 عقارات
    const isHesitant =
      behavior.favoriteProperties.length > 3 &&
      behavior.propertyViews.length > 10 &&
      contracts.length === 0; // محفوظات كثيرة لكن بدون عقود
    const isReadyToRent =
      behavior.favoriteProperties.length > 0 &&
      behavior.propertyViews.some((v) => v.viewCount > 3) &&
      contracts.length === 0; // شاهد نفس العقار أكثر من 3 مرات

    // تحديث behavior
    behavior.behaviorPatterns = {
      isComparer,
      isHesitant,
      isReadyToRent,
      userType,
      budgetLevel,
    };

    await behavior.save();

    res.status(200).json({
      success: true,
      analysis: {
        userType,
        isComparer,
        isHesitant,
        isReadyToRent,
        budgetLevel,
      },
    });
  } catch (error) {
    res.status(500).json({ message: "Error analyzing behavior", error: error.message });
  }
};

// ========================================================
// 🧠 3️⃣ نظام اقتراح العقارات (Recommendation Engine)
// ========================================================

// الحصول على اقتراحات ذكية
export const getSmartRecommendations = async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 10 } = req.query;

    // الحصول على سلوك المستخدم
    const behavior = await UserBehavior.findOne({ userId });
    const profile = await UserProfile.findOne({ userId });

    if (!behavior && !profile) {
      // إذا لم يكن هناك بيانات، نرجع أفضل العقارات
      const properties = await Property.find({ status: "available" })
        .populate("ownerId", "name email")
        .sort({ createdAt: -1 })
        .limit(parseInt(limit))
        .lean();
      return res.status(200).json({ success: true, recommendations: properties });
    }

    // بناء استعلام بناءً على التفضيلات
    const query = { status: "available" };

    // من UserProfile
    if (profile) {
      if (profile.budgetRange.min || profile.budgetRange.max) {
        query.price = {};
        if (profile.budgetRange.min) query.price.$gte = profile.budgetRange.min;
        if (profile.budgetRange.max) query.price.$lte = profile.budgetRange.max;
      }

      if (profile.preferredLocations.length > 0) {
        const cities = profile.preferredLocations.map((l) => l.city);
        query.city = { $in: cities };
      }

      if (profile.preferredPropertyTypes.length > 0) {
        const types = profile.preferredPropertyTypes.map((t) => t.type);
        query.type = { $in: types };
      }

      if (profile.bedroomPreferences.min || profile.bedroomPreferences.max) {
        query.bedrooms = {};
        if (profile.bedroomPreferences.min) query.bedrooms.$gte = profile.bedroomPreferences.min;
        if (profile.bedroomPreferences.max) query.bedrooms.$lte = profile.bedroomPreferences.max;
      }
    }

    // من UserBehavior
    if (behavior) {
      // إذا كان هناك تفضيلات من البحث
      if (behavior.preferredLocations.length > 0 && !query.city) {
        const cities = behavior.preferredLocations
          .sort((a, b) => b.frequency - a.frequency)
          .slice(0, 3)
          .map((l) => l.city);
        query.city = { $in: cities };
      }

      if (behavior.preferredPropertyTypes.length > 0 && !query.type) {
        const types = behavior.preferredPropertyTypes
          .sort((a, b) => b.frequency - a.frequency)
          .slice(0, 3)
          .map((t) => t.type);
        query.type = { $in: types };
      }

      if (behavior.priceFocus && !query.price) {
        query.price = {};
        if (behavior.priceFocus.min) query.price.$gte = behavior.priceFocus.min;
        if (behavior.priceFocus.max) query.price.$lte = behavior.priceFocus.max;
      }
    }

    // جلب العقارات
    let properties = await Property.find(query)
      .populate("ownerId", "name email")
      .lean();

    // حساب Recommendation Score لكل عقار
    const propertiesWithScores = await Promise.all(
      properties.map(async (property) => {
        const analytics = await PropertyAnalytics.findOne({ propertyId: property._id });
        let score = 0;

        // Trust Score (40%)
        if (analytics) {
          score += (analytics.trustScore.score || 50) * 0.4;
          // Recommendation Score (30%)
          score += (analytics.recommendationScore.score || 0) * 0.3;
          // Demand Level (20%)
          const demandScore = {
            low: 20,
            medium: 50,
            high: 80,
            very_high: 100,
          }[analytics.demandLevel] || 50;
          score += demandScore * 0.2;
        } else {
          score += 50 * 0.4; // Default
        }

        // Price Value (10%)
        if (property.price) {
          const marketAvg = analytics?.priceAnalysis?.averageMarketPrice || property.price;
          const priceDiff = ((marketAvg - property.price) / marketAvg) * 100;
          if (priceDiff > 10) score += 10; // أرخص من السوق
          else if (priceDiff > 0) score += 7;
          else if (priceDiff > -10) score += 5;
          else score += 2; // أغلى من السوق
        }

        return { ...property, recommendationScore: score };
      })
    );

    // ترتيب حسب Recommendation Score
    propertiesWithScores.sort((a, b) => b.recommendationScore - a.recommendationScore);

    // إضافة أسباب الاقتراح
    const recommendations = propertiesWithScores.slice(0, parseInt(limit)).map((prop) => {
      const reasons = [];
      const analytics = PropertyAnalytics.findOne({ propertyId: prop._id });

      if (prop.recommendationScore > 70) reasons.push("عقار موصى به بشدة");
      if (analytics?.trustScore?.score > 80) reasons.push("مستوى ثقة عالي");
      if (analytics?.priceAnalysis?.isUnderpriced) reasons.push("سعر ممتاز");
      if (analytics?.demandLevel === "high" || analytics?.demandLevel === "very_high")
        reasons.push("طلب مرتفع");
      if (analytics?.maintenanceAnalysis?.maintenanceLevel === "low")
        reasons.push("صيانة قليلة");

      return {
        ...prop,
        reasons,
      };
    });

    res.status(200).json({
      success: true,
      recommendations,
      userProfile: profile,
      behaviorAnalysis: behavior?.behaviorPatterns,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error getting recommendations",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 4️⃣ الترتيب الذكي (Smart Ranking)
// ========================================================

// ترتيب العقارات حسب التوافق
export const getSmartRankedProperties = async (req, res) => {
  try {
    const { userId } = req.params;
    const { filters = {} } = req.body;

    // بناء الاستعلام
    const query = { status: "available", ...filters };

    let properties = await Property.find(query)
      .populate("ownerId", "name email")
      .lean();

    // الحصول على UserProfile
    const profile = await UserProfile.findOne({ userId });
    const behavior = await UserBehavior.findOne({ userId });

    // حساب Compatibility Score لكل عقار
    const rankedProperties = await Promise.all(
      properties.map(async (property) => {
        let compatibilityScore = 0;

        // 1. Price Compatibility (30%)
        if (profile?.budgetRange && property.price) {
          const { min, max } = profile.budgetRange;
          if (property.price >= min && property.price <= max) {
            compatibilityScore += 30;
          } else if (property.price < min * 1.2 && property.price > max * 0.8) {
            compatibilityScore += 20; // قريب من النطاق
          } else {
            compatibilityScore += 5; // خارج النطاق
          }
        } else {
          compatibilityScore += 15; // Default
        }

        // 2. Location Compatibility (25%)
        if (profile?.preferredLocations.length > 0) {
          const preferredCity = profile.preferredLocations.find(
            (l) => l.city === property.city
          );
          if (preferredCity) {
            compatibilityScore += 25 * (preferredCity.priority / 10);
          }
        } else if (behavior?.preferredLocations.length > 0) {
          const preferredCity = behavior.preferredLocations.find(
            (l) => l.city === property.city
          );
          if (preferredCity) {
            compatibilityScore += 20;
          }
        } else {
          compatibilityScore += 12.5; // Default
        }

        // 3. Property Type Compatibility (20%)
        if (profile?.preferredPropertyTypes.length > 0) {
          const preferredType = profile.preferredPropertyTypes.find(
            (t) => t.type === property.type
          );
          if (preferredType) {
            compatibilityScore += 20 * (preferredType.priority / 10);
          }
        } else if (behavior?.preferredPropertyTypes.length > 0) {
          const preferredType = behavior.preferredPropertyTypes.find(
            (t) => t.type === property.type
          );
          if (preferredType) {
            compatibilityScore += 15;
          }
        } else {
          compatibilityScore += 10; // Default
        }

        // 4. Trust Score (15%)
        const analytics = await PropertyAnalytics.findOne({ propertyId: property._id });
        if (analytics) {
          compatibilityScore += (analytics.trustScore.score || 50) * 0.15;
        } else {
          compatibilityScore += 7.5; // Default
        }

        // 5. View History (10%) - إذا شاهد المستخدم هذا العقار
        if (behavior) {
          const view = behavior.propertyViews.find(
            (v) => v.propertyId.toString() === property._id.toString()
          );
          if (view) {
            compatibilityScore += Math.min(10, view.viewCount * 2); // حتى 10 نقاط
          }
        }

        return { ...property, compatibilityScore };
      })
    );

    // ترتيب حسب Compatibility Score
    rankedProperties.sort((a, b) => b.compatibilityScore - a.compatibilityScore);

    res.status(200).json({
      success: true,
      properties: rankedProperties,
      total: rankedProperties.length,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error ranking properties",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 5️⃣ التوصيف الذكي (User Profiling)
// ========================================================

// تحديث User Profile تلقائياً
export const updateUserProfile = async (req, res) => {
  try {
    const { userId } = req.params;

    const behavior = await UserBehavior.findOne({ userId });
    if (!behavior) {
      return res.status(404).json({ message: "User behavior not found" });
    }

    let profile = await UserProfile.findOne({ userId });
    if (!profile) {
      profile = new UserProfile({ userId });
    }

    // تحديث Budget Range
    if (behavior.priceFocus) {
      profile.budgetRange = {
        min: behavior.priceFocus.min || 0,
        max: behavior.priceFocus.max || 1000000,
        preferred: (behavior.priceFocus.min + behavior.priceFocus.max) / 2,
        currency: behavior.priceFocus.currency || "USD",
        confidence: behavior.searchHistory.length > 5 ? 80 : 50,
      };
    }

    // تحديث Preferred Locations
    if (behavior.preferredLocations.length > 0) {
      profile.preferredLocations = behavior.preferredLocations
        .sort((a, b) => b.frequency - a.frequency)
        .slice(0, 5)
        .map((l) => ({
          city: l.city,
          priority: Math.min(10, l.frequency),
          lastSearched: l.lastSearched,
        }));
    }

    // تحديث Preferred Property Types
    if (behavior.preferredPropertyTypes.length > 0) {
      profile.preferredPropertyTypes = behavior.preferredPropertyTypes
        .sort((a, b) => b.frequency - a.frequency)
        .slice(0, 5)
        .map((t) => ({
          type: t.type,
          priority: Math.min(10, t.frequency),
          lastSearched: t.lastSearched,
        }));
    }

    // تحديث User Type
    profile.userType = behavior.behaviorPatterns.userType || "unknown";

    // تحديث Price Sensitivity
    const contracts = await Contract.find({ tenantId: userId });
    if (contracts.length > 0) {
      const avgRent = contracts.reduce((sum, c) => sum + (c.rentAmount || 0), 0) / contracts.length;
      if (avgRent < 300) profile.priceSensitivity = "high";
      else if (avgRent < 600) profile.priceSensitivity = "medium";
      else profile.priceSensitivity = "low";
    }

    profile.lastUpdated = new Date();
    await profile.save();

    res.status(200).json({
      success: true,
      profile,
      message: "User profile updated",
    });
  } catch (error) {
    res.status(500).json({
      message: "Error updating profile",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 6️⃣ الذكاء المالي (Financial Intelligence)
// ========================================================

// تحليل السعر مقابل السوق
export const analyzePropertyPrice = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // جلب عقارات مشابهة في نفس المدينة
    const similarProperties = await Property.find({
      city: property.city,
      type: property.type,
      operation: property.operation,
      _id: { $ne: propertyId },
      status: "available",
    }).lean();

    // حساب متوسط السعر
    const avgPrice =
      similarProperties.length > 0
        ? similarProperties.reduce((sum, p) => sum + (p.price || 0), 0) /
          similarProperties.length
        : property.price;

    const priceDiff = property.price - avgPrice;
    const priceDiffPercent = (priceDiff / avgPrice) * 100;

    // تحديث PropertyAnalytics
    let analytics = await PropertyAnalytics.findOne({ propertyId });
    if (!analytics) {
      analytics = new PropertyAnalytics({ propertyId });
    }

    analytics.priceAnalysis = {
      currentPrice: property.price,
      averageMarketPrice: avgPrice,
      priceVsMarket: priceDiffPercent,
      isOverpriced: priceDiffPercent > 15,
      isUnderpriced: priceDiffPercent < -15,
      priceHistory: [
        ...(analytics.priceAnalysis?.priceHistory || []),
        {
          price: property.price,
          date: new Date(),
        },
      ],
    };

    await analytics.save();

    res.status(200).json({
      success: true,
      analysis: {
        currentPrice: property.price,
        averageMarketPrice: avgPrice,
        priceDifference: priceDiff,
        priceDifferencePercent: priceDiffPercent.toFixed(2),
        isOverpriced: priceDiffPercent > 15,
        isUnderpriced: priceDiffPercent < -15,
        recommendation:
          priceDiffPercent > 15
            ? "السعر أعلى من متوسط السوق"
            : priceDiffPercent < -15
            ? "السعر أقل من متوسط السوق (فرصة جيدة)"
            : "السعر في المتوسط",
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error analyzing price",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 7️⃣ ذكاء الموثوقية (Trust Intelligence)
// ========================================================

// حساب Trust Score للعقار
export const calculateTrustScore = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // جلب البيانات
    const reviews = await Review.find({ propertyId });
    const maintenanceRequests = await MaintenanceRequest.find({ propertyId });
    const contracts = await Contract.find({ propertyId: property._id });

    // حساب Owner Rating
    const ownerProperties = await Property.find({ ownerId: property.ownerId });
    const ownerReviews = await Review.find({
      propertyId: { $in: ownerProperties.map((p) => p._id) },
    });
    const ownerRating =
      ownerReviews.length > 0
        ? ownerReviews.reduce((sum, r) => sum + r.rating, 0) / ownerReviews.length
        : 3; // Default 3/5

    // حساب Review Rating
    const reviewRating =
      reviews.length > 0
        ? reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length
        : 3;

    // حساب Complaint Count
    const complaintCount = maintenanceRequests.filter((m) => m.status === "pending").length;

    // حساب Contract Stability
    let contractStability = 50; // Default
    if (contracts.length > 0) {
      const activeContracts = contracts.filter((c) => c.status === "active");
      const avgDuration =
        activeContracts.length > 0
          ? activeContracts.reduce((sum, c) => {
              const duration =
                (new Date(c.endDate) - new Date(c.startDate)) / (1000 * 60 * 60 * 24);
              return sum + duration;
            }, 0) / activeContracts.length
          : 0;
      contractStability = Math.min(100, (avgDuration / 365) * 100); // 365 يوم = 100%
    }

    // حساب Trust Score
    let trustScore = 50; // Base score

    // Owner Rating (25%)
    trustScore += (ownerRating / 5) * 25;

    // Review Rating (25%)
    trustScore += (reviewRating / 5) * 25;

    // Verified (10%)
    if (property.verified) trustScore += 10;

    // Complaint Count (15%) - أقل شكاوى = أعلى نقاط
    const complaintPenalty = Math.min(15, complaintCount * 3);
    trustScore -= complaintPenalty;

    // Contract Stability (15%)
    trustScore += (contractStability / 100) * 15;

    // Maintenance Resolution (10%)
    const resolvedCount = maintenanceRequests.filter((m) => m.status === "resolved").length;
    const resolutionRate =
      maintenanceRequests.length > 0 ? resolvedCount / maintenanceRequests.length : 1;
    trustScore += resolutionRate * 10;

    trustScore = Math.max(0, Math.min(100, trustScore)); // Clamp 0-100

    // تحديث PropertyAnalytics
    let analytics = await PropertyAnalytics.findOne({ propertyId });
    if (!analytics) {
      analytics = new PropertyAnalytics({ propertyId });
    }

    analytics.trustScore = {
      score: trustScore,
      factors: {
        ownerRating: ownerRating * 20, // Convert to 0-100
        complaintCount,
        maintenanceCount: maintenanceRequests.length,
        averageResponseTime: 0, // TODO: Calculate from timestamps
        reviewRating: reviewRating * 20,
        verified: property.verified,
        contractStability,
      },
      lastCalculated: new Date(),
    };

    await analytics.save();

    res.status(200).json({
      success: true,
      trustScore: {
        score: trustScore,
        factors: analytics.trustScore.factors,
        breakdown: {
          ownerRating: ownerRating,
          reviewRating: reviewRating,
          verified: property.verified,
          complaints: complaintCount,
          contractStability: contractStability,
        },
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error calculating trust score",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 8️⃣ ذكاء الصيانة والجودة
// ========================================================

// تحليل الصيانة
export const analyzeMaintenance = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const maintenanceRequests = await MaintenanceRequest.find({ propertyId });

    const totalRequests = maintenanceRequests.length;
    const resolvedCount = maintenanceRequests.filter((m) => m.status === "resolved").length;
    const pendingCount = maintenanceRequests.filter((m) => m.status === "pending").length;

    // حساب متوسط وقت الحل
    const resolvedRequests = maintenanceRequests.filter((m) => m.status === "resolved");
    let averageResolutionTime = 0;
    if (resolvedRequests.length > 0) {
      const totalTime = resolvedRequests.reduce((sum, m) => {
        const resolutionTime =
          (new Date(m.updatedAt) - new Date(m.createdAt)) / (1000 * 60 * 60 * 24); // بالأيام
        return sum + resolutionTime;
      }, 0);
      averageResolutionTime = totalTime / resolvedRequests.length;
    }

    // تحديد مستوى الصيانة
    let maintenanceLevel = "low";
    if (totalRequests > 10) maintenanceLevel = "high";
    else if (totalRequests > 5) maintenanceLevel = "medium";

    // تحديث PropertyAnalytics
    let analytics = await PropertyAnalytics.findOne({ propertyId });
    if (!analytics) {
      analytics = new PropertyAnalytics({ propertyId });
    }

    analytics.maintenanceAnalysis = {
      totalRequests,
      resolvedCount,
      pendingCount,
      averageResolutionTime,
      maintenanceLevel,
      recurringIssues: [], // TODO: Analyze descriptions for recurring issues
    };

    await analytics.save();

    res.status(200).json({
      success: true,
      analysis: {
        totalRequests,
        resolvedCount,
        pendingCount,
        averageResolutionTime: averageResolutionTime.toFixed(2),
        maintenanceLevel,
        resolutionRate: totalRequests > 0 ? (resolvedCount / totalRequests) * 100 : 100,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error analyzing maintenance",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 9️⃣ الذكاء الزمني (Time-Based Intelligence)
// ========================================================

// تحليل الطلب الموسمي
export const analyzeSeasonalDemand = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // جلب بيانات الزيارات من PropertyAnalytics
    const analytics = await PropertyAnalytics.findOne({ propertyId });

    // تحديد الموسم الحالي
    const now = new Date();
    const month = now.getMonth() + 1; // 1-12

    let season = "normal";
    let demandMultiplier = 1;

    // في فلسطين: طلاب يبحثون في أغسطس-سبتمبر، عائلات في الصيف
    if (month >= 8 && month <= 9) {
      season = "student_season";
      demandMultiplier = 1.5;
    } else if (month >= 6 && month <= 7) {
      season = "summer_season";
      demandMultiplier = 1.3;
    }

    // تحديث Demand Level
    if (analytics) {
      let demandLevel = "medium";
      const viewCount = analytics.viewStats.totalViews || 0;
      const favoriteCount = analytics.favoriteStats.totalFavorites || 0;

      const demandScore = (viewCount * 0.5 + favoriteCount * 2) * demandMultiplier;

      if (demandScore > 50) demandLevel = "very_high";
      else if (demandScore > 30) demandLevel = "high";
      else if (demandScore > 10) demandLevel = "medium";
      else demandLevel = "low";

      analytics.demandLevel = demandLevel;
      analytics.demandLevel.factors = {
        viewCount,
        favoriteCount,
        inquiryCount: 0, // TODO: Track inquiries
        searchFrequency: 0, // TODO: Track search frequency
      };
      analytics.demandLevel.lastCalculated = new Date();
      await analytics.save();
    }

    res.status(200).json({
      success: true,
      analysis: {
        currentSeason: season,
        demandMultiplier,
        month,
        recommendation:
          season === "student_season"
            ? "موسم الطلاب - طلب مرتفع"
            : season === "summer_season"
            ? "موسم الصيف - طلب مرتفع"
            : "موسم عادي",
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error analyzing seasonal demand",
      error: error.message,
    });
  }
};

// ========================================================
// 🔔 10️⃣ نظام التنبيهات الذكية
// ========================================================

// الحصول على التنبيهات الذكية
export const getSmartNotifications = async (req, res) => {
  try {
    const { userId } = req.params;

    const behavior = await UserBehavior.findOne({ userId });
    const profile = await UserProfile.findOne({ userId });

    if (!behavior) {
      return res.status(200).json({ success: true, notifications: [] });
    }

    const notifications = [];

    // 1. عقار مشابه نزل سعره
    const favoritePropertyIds = behavior.favoriteProperties.map((f) => f.propertyId);
    for (const propertyId of favoritePropertyIds) {
      const analytics = await PropertyAnalytics.findOne({ propertyId });
      if (analytics?.priceAnalysis?.priceHistory?.length > 1) {
        const priceHistory = analytics.priceAnalysis.priceHistory;
        const latestPrice = priceHistory[priceHistory.length - 1].price;
        const previousPrice = priceHistory[priceHistory.length - 2].price;

        if (latestPrice < previousPrice) {
          const priceDrop = ((previousPrice - latestPrice) / previousPrice) * 100;
          if (priceDrop > 5) {
            // انخفاض أكثر من 5%
            notifications.push({
              type: "price_drop",
              propertyId,
              message: `عقار محفوظ نزل سعره بنسبة ${priceDrop.toFixed(1)}%`,
              createdAt: new Date(),
            });
          }
        }
      }
    }

    // 2. إضافة عقار يناسب تفضيلاتك
    // TODO: Check for new properties matching preferences

    // 3. فرصة قصيرة (طلب مرتفع)
    const viewedProperties = behavior.propertyViews
      .sort((a, b) => b.viewCount - a.viewCount)
      .slice(0, 5)
      .map((v) => v.propertyId);

    for (const propertyId of viewedProperties) {
      const analytics = await PropertyAnalytics.findOne({ propertyId });
      if (analytics?.demandLevel === "high" || analytics?.demandLevel === "very_high") {
        notifications.push({
          type: "high_demand",
          propertyId,
          message: "عقار شاهدته - طلب مرتفع عليه",
          createdAt: new Date(),
        });
      }
    }

    // 4. عقار موثوق متاح
    // TODO: Check for high trust score properties

    res.status(200).json({
      success: true,
      notifications: notifications.slice(0, 10), // Limit to 10
    });
  } catch (error) {
    res.status(500).json({
      message: "Error getting notifications",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 1️⃣1️⃣ ذكاء المالك (Owner Intelligence)
// ========================================================

// تحليل أداء عقار للمالك
export const getOwnerPropertyInsights = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    const analytics = await PropertyAnalytics.findOne({ propertyId });
    if (!analytics) {
      return res.status(200).json({
        success: true,
        insights: {
          message: "لا توجد بيانات كافية للتحليل",
        },
      });
    }

    const insights = {
      performance: {
        viewCount: analytics.viewStats.totalViews,
        favoriteCount: analytics.favoriteStats.totalFavorites,
        trustScore: analytics.trustScore.score,
        demandLevel: analytics.demandLevel,
      },
      recommendations: [],
    };

    // اقتراحات تحسين السعر
    if (analytics.priceAnalysis?.isOverpriced) {
      insights.recommendations.push({
        type: "price",
        message: "السعر أعلى من متوسط السوق - يُنصح بتخفيض السعر",
        suggestedPrice: analytics.priceAnalysis.averageMarketPrice,
      });
    }

    // اقتراحات تحسين Trust Score
    if (analytics.trustScore.score < 60) {
      insights.recommendations.push({
        type: "trust",
        message: "مستوى الثقة منخفض - يُنصح بتحسين الاستجابة للصيانة",
      });
    }

    // اقتراحات تحسين الطلب
    if (analytics.demandLevel === "low") {
      insights.recommendations.push({
        type: "demand",
        message: "الطلب منخفض - يُنصح بتحسين الصور والوصف",
      });
    }

    res.status(200).json({
      success: true,
      insights,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error getting owner insights",
      error: error.message,
    });
  }
};

// ========================================================
// 🧠 1️⃣2️⃣ ذكاء الإدارة (Admin Intelligence)
// ========================================================

// إحصائيات النظام للأدمن
export const getAdminIntelligence = async (req, res) => {
  try {
    // المناطق الأعلى طلبًا
    const properties = await Property.find({ status: "available" }).lean();
    const cityDemand = {};
    for (const property of properties) {
      if (!cityDemand[property.city]) {
        cityDemand[property.city] = 0;
      }
      const analytics = await PropertyAnalytics.findOne({ propertyId: property._id });
      if (analytics) {
        cityDemand[property.city] += analytics.viewStats.totalViews || 0;
      }
    }

    const topCities = Object.entries(cityDemand)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([city, demand]) => ({ city, demand }));

    // العقارات المشبوهة (Trust Score منخفض)
    const lowTrustProperties = await PropertyAnalytics.find({
      "trustScore.score": { $lt: 40 },
    })
      .populate("propertyId")
      .limit(10)
      .lean();

    // الأسعار غير المنطقية
    const suspiciousPrices = [];
    for (const property of properties.slice(0, 50)) {
      // Sample check
      const analytics = await PropertyAnalytics.findOne({ propertyId: property._id });
      if (analytics?.priceAnalysis?.isOverpriced) {
        const priceDiff = analytics.priceAnalysis.priceVsMarket;
        if (priceDiff > 50) {
          // أكثر من 50% من المتوسط
          suspiciousPrices.push({
            propertyId: property._id,
            currentPrice: property.price,
            marketAverage: analytics.priceAnalysis.averageMarketPrice,
            difference: priceDiff,
          });
        }
      }
    }

    res.status(200).json({
      success: true,
      intelligence: {
        topCitiesByDemand: topCities,
        suspiciousProperties: lowTrustProperties.map((a) => ({
          propertyId: a.propertyId?._id,
          trustScore: a.trustScore.score,
        })),
        suspiciousPrices: suspiciousPrices.slice(0, 10),
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error getting admin intelligence",
      error: error.message,
    });
  }
};
