// utils/aiTools.js
// AI Tools Functions - يمكن للـ AI استدعاؤها

import Property from "../models/Property.js";
import UserBehavior from "../models/UserBehavior.js";
import Contract from "../models/Contract.js";

/**
 * Tool: الحصول على أكثر العقارات مشاهدة
 */
export async function getTopViewedProperties(userId, limit = 5) {
  try {
    const behavior = await UserBehavior.findOne({ userId });
    if (!behavior || !behavior.propertyViews || behavior.propertyViews.length === 0) {
      return { success: false, message: "لا توجد بيانات مشاهدة متاحة" };
    }

    const sortedViews = behavior.propertyViews
      .sort((a, b) => (b.viewCount || 0) - (a.viewCount || 0))
      .slice(0, limit);

    const propertyIds = sortedViews.map(view => view.propertyId);
    const properties = await Property.find({ _id: { $in: propertyIds } })
      .select('title city price type operation area bedrooms bathrooms images')
      .lean();

    return {
      success: true,
      properties: properties.map((prop, idx) => ({
        ...prop,
        viewCount: sortedViews[idx]?.viewCount || 0,
      })),
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Tool: الحصول على عقارات موصى بها
 */
export async function getRecommendedProperties(userId, budget, city) {
  try {
    const query = {
      status: "available",
    };

    if (city) {
      query.city = new RegExp(city, "i");
    }

    if (budget) {
      query.price = { $lte: parseFloat(budget) };
    }

    const properties = await Property.find(query)
      .select('title city price type operation area bedrooms bathrooms images description')
      .sort({ createdAt: -1 })
      .limit(10)
      .lean();

    // إضافة معلومات إضافية من UserBehavior إذا كان متاحاً
    const behavior = await UserBehavior.findOne({ userId });
    if (behavior) {
      properties.forEach(prop => {
        const viewData = behavior.propertyViews?.find(
          v => v.propertyId?.toString() === prop._id.toString()
        );
        if (viewData) {
          prop.viewCount = viewData.viewCount || 0;
        }
      });
    }

    return {
      success: true,
      properties,
      filters: { budget, city },
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Tool: فحص توفر عقار
 */
export async function checkAvailability(propertyId, startDate, endDate) {
  try {
    const property = await Property.findById(propertyId);
    if (!property) {
      return { success: false, message: "العقار غير موجود" };
    }

    // البحث عن عقود نشطة في هذا التاريخ
    const activeContracts = await Contract.find({
      propertyId: propertyId,
      status: "active",
      $or: [
        {
          startDate: { $lte: new Date(endDate) },
          endDate: { $gte: new Date(startDate) },
        },
      ],
    });

    const isAvailable = activeContracts.length === 0;

    return {
      success: true,
      propertyId,
      isAvailable,
      conflictingContracts: activeContracts.length,
      message: isAvailable
        ? "العقار متاح في الفترة المحددة"
        : `العقار غير متاح (${activeContracts.length} عقد نشط)`,
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Tool: حساب تقدير الإيجار
 */
export async function calculateRentEstimate(propertyId, months = 12) {
  try {
    const property = await Property.findById(propertyId);
    if (!property) {
      return { success: false, message: "العقار غير موجود" };
    }

    if (property.operation !== "rent" || !property.price) {
      return { success: false, message: "هذا العقار غير متاح للإيجار" };
    }

    const monthlyRent = property.price;
    const totalRent = monthlyRent * months;
    const estimatedDeposit = monthlyRent * 2; // عادة وديعة شهرين

    return {
      success: true,
      propertyId,
      monthlyRent,
      totalRent,
      estimatedDeposit,
      months,
      breakdown: {
        monthly: monthlyRent,
        total: totalRent,
        deposit: estimatedDeposit,
      },
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Tool: الحصول على إحصائيات عقار
 */
export async function getPropertyStats(propertyId) {
  try {
    const property = await Property.findById(propertyId);
    if (!property) {
      return { success: false, message: "العقار غير موجود" };
    }

    // عدد العقود
    const contractsCount = await Contract.countDocuments({ propertyId });
    const activeContracts = await Contract.countDocuments({
      propertyId,
      status: "active",
    });

    // إجمالي الإيجار (من العقود النشطة)
    const activeContractsData = await Contract.find({
      propertyId,
      status: "active",
    });
    const totalRevenue = activeContractsData.reduce(
      (sum, contract) => sum + (contract.rentAmount || 0),
      0
    );

    return {
      success: true,
      propertyId,
      stats: {
        totalContracts: contractsCount,
        activeContracts,
        totalRevenue,
        status: property.status,
        price: property.price,
      },
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Tool: الحصول على تفضيلات المستخدم
 */
export async function getUserPreferences(userId) {
  try {
    const behavior = await UserBehavior.findOne({ userId });
    if (!behavior) {
      return { success: false, message: "لا توجد بيانات سلوكية" };
    }

    const preferences = {
      preferredCities: behavior.preferredLocations?.map(loc => loc.city) || [],
      priceRange: behavior.priceFocus || null,
      favoritePropertiesCount: behavior.favoriteProperties?.length || 0,
      totalViews: behavior.propertyViews?.length || 0,
    };

    return {
      success: true,
      preferences,
    };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/**
 * Mapping بين Tool Names والـ Functions
 */
export const AI_TOOLS = {
  getTopViewedProperties: {
    function: getTopViewedProperties,
    description: "الحصول على أكثر العقارات مشاهدة من قبل المستخدم",
    parameters: {
      userId: { type: "string", required: true },
      limit: { type: "number", required: false, default: 5 },
    },
  },
  getRecommendedProperties: {
    function: getRecommendedProperties,
    description: "الحصول على عقارات موصى بها بناءً على الميزانية والمدينة",
    parameters: {
      userId: { type: "string", required: true },
      budget: { type: "number", required: false },
      city: { type: "string", required: false },
    },
  },
  checkAvailability: {
    function: checkAvailability,
    description: "فحص توفر عقار في فترة معينة",
    parameters: {
      propertyId: { type: "string", required: true },
      startDate: { type: "string", required: true },
      endDate: { type: "string", required: true },
    },
  },
  calculateRentEstimate: {
    function: calculateRentEstimate,
    description: "حساب تقدير الإيجار لعقار لفترة معينة",
    parameters: {
      propertyId: { type: "string", required: true },
      months: { type: "number", required: false, default: 12 },
    },
  },
  getPropertyStats: {
    function: getPropertyStats,
    description: "الحصول على إحصائيات عقار (عقود، إيرادات، إلخ)",
    parameters: {
      propertyId: { type: "string", required: true },
    },
  },
  getUserPreferences: {
    function: getUserPreferences,
    description: "الحصول على تفضيلات المستخدم (مدن، أسعار، إلخ)",
    parameters: {
      userId: { type: "string", required: true },
    },
  },
};
