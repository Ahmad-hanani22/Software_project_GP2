import User from "../models/User.js";
import Property from "../models/Property.js";
import Contract from "../models/Contract.js";
import Payment from "../models/Payment.js";
import MaintenanceRequest from "../models/MaintenanceRequest.js";
import Complaint from "../models/Complaint.js";
import Review from "../models/Review.js";
import Notification from "../models/Notification.js";

/* =========================================================
 📊 لوحة تحكم الأدمن (Summary + Analytics)
========================================================= */
export const getDashboardStats = async (req, res) => {
  try {
    // ✅ الإحصائيات العامة (Summary)
    const [
      users,
      properties,
      contracts,
      payments,
      maintenances,
      complaints,
      reviews,
      notifications,
    ] = await Promise.all([
      User.countDocuments(),
      Property.countDocuments(),
      Contract.countDocuments(),
      Payment.countDocuments(),
      MaintenanceRequest.countDocuments(),
      Complaint.countDocuments(),
      Review.countDocuments(),
      Notification.countDocuments(),
    ]);

    // ✅ بيانات تفصيلية (Latest)
    const latestUsers = await User.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .select("name email role createdAt");
    const latestProperties = await Property.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .select("title price createdAt");
    const latestComplaints = await Complaint.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .select("description status createdAt");
    const latestReviews = await Review.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .populate("userId", "name")
      .select("rating comment createdAt");

    // ✅ التحليلات (Analytics)
    const userStats = await User.aggregate([
      { $group: { _id: "$role", count: { $sum: 1 } } },
    ]);
    const propertyStats = await Property.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]);
    const paymentStats = await Payment.aggregate([
      {
        $group: {
          _id: "$status",
          total: { $sum: "$amount" },
          count: { $sum: 1 },
        },
      },
    ]);
    const contractStats = await Contract.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]);
    const maintenanceStats = await MaintenanceRequest.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]);
    const complaintStats = await Complaint.aggregate([
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]);

    const totalRevenue = await Payment.aggregate([
      { $match: { status: "paid" } },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]);

    res.status(200).json({
      message: "✅ Admin Dashboard loaded successfully",
      summary: {
        users,
        properties,
        contracts,
        payments,
        maintenances,
        complaints,
        reviews,
        notifications,
      },
      latest: {
        users: latestUsers,
        properties: latestProperties,
        complaints: latestComplaints,
        reviews: latestReviews,
      },
      analytics: {
        userStats,
        propertyStats,
        paymentStats,
        contractStats,
        maintenanceStats,
        complaintStats,
        totalRevenue: totalRevenue[0]?.total || 0,
      },
    });
  } catch (error) {
    console.error("❌ Error fetching admin dashboard:", error);
    res
      .status(500)
      .json({ message: "❌ Error fetching dashboard", error: error.message });
  }
};
