import User from "../models/User.js";
import Property from "../models/Property.js";
import Contract from "../models/Contract.js";
import Payment from "../models/Payment.js";
import MaintenanceRequest from "../models/MaintenanceRequest.js";
import Complaint from "../models/Complaint.js";
import Review from "../models/Review.js";
import Notification from "../models/Notification.js";
import asyncHandler from 'express-async-handler'; // إذا كنت تستخدمه لمعالجة الأخطاء بشكل مريح

/* =========================================================
 📊 لوحة تحكم الأدمن (Summary + Analytics + Latest)
========================================================= */
export const getDashboardStats = asyncHandler(async (req, res) => {
  try {
    // ✅ الإحصائيات العامة (Summary)
    const [
      totalUsers,
      totalLandlords,
      totalTenants,
      totalProperties,
      totalContracts,
      totalPayments,
      totalMaintenances,
      totalComplaints,
      totalReviews,
      totalNotifications,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ role: "landlord" }),
      User.countDocuments({ role: "tenant" }),
      Property.countDocuments(),
      Contract.countDocuments(),
      Payment.countDocuments(),
      MaintenanceRequest.countDocuments(),
      Complaint.countDocuments(),
      Review.countDocuments(),
      Notification.countDocuments(),
    ]);

    // ✅ التحليلات (Analytics) - تم إضافة جميع aggregations المطلوبة هنا
    const [
      userStats,
      propertyStats,
      contractStats,
      paymentStats,
      maintenanceStats,
      complaintStats,
      totalRevenueResult,
    ] = await Promise.all([
      User.aggregate([
        { $group: { _id: "$role", count: { $sum: 1 } } },
      ]),
      Property.aggregate([
        { $group: { _id: "$status", count: { $sum: 1 } } },
      ]),
      Contract.aggregate([
        { $group: { _id: "$status", count: { $sum: 1 } } },
      ]),
      Payment.aggregate([
        {
          $group: {
            _id: "$status",
            total: { $sum: "$amount" },
            count: { $sum: 1 },
          },
        },
      ]),
      MaintenanceRequest.aggregate([
        { $group: { _id: "$status", count: { $sum: 1 } } },
      ]),
      Complaint.aggregate([
        { $group: { _id: "$status", count: { $sum: 1 } } },
      ]),
      Payment.aggregate([
        { $match: { status: "paid" } },
        { $group: { _id: null, total: { $sum: "$amount" } } },
      ]),
    ]);

    const totalRevenue = totalRevenueResult[0]?.total || 0;

    // ✅ أحدث الإدخالات (Latest)
    const [
      latestUsers,
      latestProperties,
      latestContracts,
      latestComplaints,
      latestPayments,
      latestReviews,
    ] = await Promise.all([
      User.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .select("name email role createdAt"),
      Property.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .select("title price status createdAt"),
      Contract.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .select("status startDate endDate createdAt"),
      Complaint.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .select("description status createdAt"),
      Payment.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .select("amount status createdAt"),
      Review.find()
        .sort({ createdAt: -1 })
        .limit(5)
        .populate("reviewerId", "name") // ✅ تم التأكد من اسم الحقل
        .populate("propertyId", "title") // ✅ تم التأكد من اسم الحقل
        .select("rating comment createdAt reviewerId propertyId"), // ✅ يجب تحديد populate fields في select أيضا
    ]);

    // ✅ تجميع النتيجة النهائية
    res.status(200).json({
      message: "✅ Admin Dashboard loaded successfully",
      summary: {
        totalUsers,
        totalLandlords,
        totalTenants,
        totalProperties,
        totalContracts,
        totalPayments,
        totalMaintenances,
        totalComplaints,
        totalReviews,
        totalNotifications,
      },
      analytics: {
        userStats, // ✅ تم إضافته مرة أخرى
        propertyStats,
        contractStats,
        paymentStats,
        maintenanceStats, // ✅ تم إضافته مرة أخرى
        complaintStats,   // ✅ تم إضافته مرة أخرى
        totalRevenue,
      },
      latest: {
        users: latestUsers,
        properties: latestProperties,
        contracts: latestContracts,
        payments: latestPayments,
        complaints: latestComplaints,
        reviews: latestReviews,
      },
    });
  } catch (error) {
    console.error("❌ Error fetching admin dashboard:", error);
    res.status(500).json({
      message: "❌ Error fetching dashboard",
      error: error.message,
    });
  }
});