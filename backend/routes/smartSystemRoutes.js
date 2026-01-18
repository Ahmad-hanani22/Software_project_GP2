import express from "express";
import {
  trackPropertyView,
  toggleFavorite,
  trackSearch,
  analyzeUserBehavior,
  getSmartRecommendations,
  getSmartRankedProperties,
  updateUserProfile,
  analyzePropertyPrice,
  calculateTrustScore,
  analyzeMaintenance,
  analyzeSeasonalDemand,
  getSmartNotifications,
  getOwnerPropertyInsights,
  getAdminIntelligence,
} from "../controllers/smartSystemController.js";
import { protect, authorizeRoles } from "../middleware/authMiddleware.js";

const router = express.Router();

// ========================================================
// 🧠 1️⃣ جمع البيانات (Data Collection) - Public
// ========================================================
router.post("/track-view", trackPropertyView); // يمكن أن يكون public أو protected
router.post("/toggle-favorite", protect, toggleFavorite);
router.post("/track-search", protect, trackSearch);

// ========================================================
// 🧠 2️⃣ تحليل السلوك (User Behavior Analysis)
// ========================================================
router.get("/analyze-behavior/:userId", protect, analyzeUserBehavior);

// ========================================================
// 🧠 3️⃣ نظام الاقتراحات (Recommendation Engine)
// ========================================================
router.get("/recommendations/:userId", protect, getSmartRecommendations);

// ========================================================
// 🧠 4️⃣ الترتيب الذكي (Smart Ranking)
// ========================================================
router.post("/rank-properties/:userId", protect, getSmartRankedProperties);

// ========================================================
// 🧠 5️⃣ التوصيف الذكي (User Profiling)
// ========================================================
router.put("/update-profile/:userId", protect, updateUserProfile);

// ========================================================
// 🧠 6️⃣ الذكاء المالي (Financial Intelligence)
// ========================================================
router.get("/analyze-price/:propertyId", analyzePropertyPrice);

// ========================================================
// 🧠 7️⃣ ذكاء الموثوقية (Trust Intelligence)
// ========================================================
router.get("/trust-score/:propertyId", calculateTrustScore);

// ========================================================
// 🧠 8️⃣ ذكاء الصيانة والجودة
// ========================================================
router.get("/analyze-maintenance/:propertyId", protect, analyzeMaintenance);

// ========================================================
// 🧠 9️⃣ الذكاء الزمني (Time-Based Intelligence)
// ========================================================
router.get("/seasonal-demand/:propertyId", analyzeSeasonalDemand);

// ========================================================
// 🔔 10️⃣ نظام التنبيهات الذكية
// ========================================================
router.get("/notifications/:userId", protect, getSmartNotifications);

// ========================================================
// 🧠 1️⃣1️⃣ ذكاء المالك (Owner Intelligence)
// ========================================================
router.get("/owner-insights/:propertyId", protect, getOwnerPropertyInsights);

// ========================================================
// 🧠 1️⃣2️⃣ ذكاء الإدارة (Admin Intelligence)
// ========================================================
router.get("/admin-intelligence", protect, authorizeRoles("admin"), getAdminIntelligence);

export default router;
