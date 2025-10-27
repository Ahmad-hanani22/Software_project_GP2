import Notification from "../models/Notification.js";


export const getNotificationDashboard = async (req, res) => {
  try {
    const userId = req.user._id;

    const notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 })
      .limit(20)
      .lean();

    const unreadCount = await Notification.countDocuments({
      userId,
      isRead: false,
    });

    const groupedByType = notifications.reduce((acc, n) => {
      acc[n.type] = acc[n.type] ? [...acc[n.type], n] : [n];
      return acc;
    }, {});

    res.status(200).json({
      message: "✅ Notification dashboard fetched successfully",
      summary: {
        total: notifications.length,
        unreadCount,
        types: Object.keys(groupedByType),
      },
      notifications,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching notification dashboard",
      error: error.message,
    });
  }
};


export const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user._id;
    const result = await Notification.updateMany(
      { userId, isRead: false },
      { $set: { isRead: true } }
    );

    res.status(200).json({
      message: "✅ All notifications marked as read",
      updated: result.modifiedCount,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error marking notifications as read",
      error: error.message,
    });
  }
};
