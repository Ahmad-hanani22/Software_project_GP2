// middleware/rateLimiter.js
// Rate Limiter للـ AI Endpoints لتجنب الاستخدام المفرط

// Simple in-memory rate limiter (يمكن استخدام Redis لاحقاً للإنتاج)
const requests = new Map();

/**
 * Rate Limiter Middleware
 * @param {number} maxRequests - عدد الطلبات المسموحة
 * @param {number} windowMs - النافذة الزمنية بالميلي ثانية
 */
export const rateLimiter = (maxRequests = 10, windowMs = 60 * 1000) => {
  return (req, res, next) => {
    const userId = req.user?._id?.toString() || req.ip || "anonymous";
    const now = Date.now();
    const key = `ai_${userId}`;

    // تنظيف الطلبات القديمة
    if (requests.has(key)) {
      const userRequests = requests.get(key);
      requests.set(
        key,
        userRequests.filter((timestamp) => now - timestamp < windowMs)
      );
    }

    const userRequests = requests.get(key) || [];
    const recentRequests = userRequests.filter(
      (timestamp) => now - timestamp < windowMs
    );

    if (recentRequests.length >= maxRequests) {
      return res.status(429).json({
        success: false,
        message: `تم تجاوز الحد المسموح. يرجى المحاولة بعد ${Math.ceil((recentRequests[0] + windowMs - now) / 1000)} ثانية.`,
        retryAfter: Math.ceil((recentRequests[0] + windowMs - now) / 1000),
      });
    }

    // إضافة الطلب الحالي
    recentRequests.push(now);
    requests.set(key, recentRequests);

    next();
  };
};
