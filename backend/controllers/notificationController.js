import Notification from "../models/Notification.js";


export const createNotification = async (req, res) => {
  try {
    const { userId, message, type, actorId, entityType, entityId, link } =
      req.body;

    if (!userId || !message) {
      return res
        .status(400)
        .json({ message: "❌ userId and message are required" });
    }

    const notification = new Notification({
      userId,
      message,
      type,
      actorId,
      entityType,
      entityId,
      link,
    });

    await notification.save();

    res.status(201).json({
      message: "✅ Notification created successfully",
      notification,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error creating notification",
      error: error.message,
    });
  }
};

export const getAllNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find()
      .populate("userId", "name email role")
      .sort({ createdAt: -1 });

    res.status(200).json(notifications);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching notifications",
      error: error.message,
    });
  }
};


export const getUserNotifications = async (req, res) => {
  try {
    const { userId } = req.params;

    const notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 })
      .limit(50); // عرض آخر 50 إشعار فقط

    res.status(200).json(notifications);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching user notifications",
      error: error.message,
    });
  }
};


export const getUnreadCount = async (req, res) => {
  try {
    const { userId } = req.params;
    const unread = await Notification.countDocuments({
      userId,
      isRead: false,
    });

    res.status(200).json({ unread });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error counting unread notifications",
      error: error.message,
    });
  }
};


export const markAsRead = async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);
    if (!notification)
      return res.status(404).json({ message: "❌ Notification not found" });

    if (
      req.user.role !== "admin" &&
      String(notification.userId) !== String(req.user._id)
    ) {
      return res.status(403).json({ message: "🚫 Not allowed" });
    }

    notification.isRead = true;
    await notification.save();

    res.status(200).json({
      message: "✅ Notification marked as read",
      notification,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating notification",
      error: error.message,
    });
  }
};


export const markAllAsRead = async (req, res) => {
  try {
    const { userId } = req.params;

    if (req.user.role !== "admin" && String(req.user._id) !== String(userId)) {
      return res.status(403).json({ message: "🚫 Not allowed" });
    }

    await Notification.updateMany(
      { userId, isRead: false },
      { $set: { isRead: true } }
    );

    res.status(200).json({ message: "✅ All notifications marked as read" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating notifications",
      error: error.message,
    });
  }
};


export const deleteNotification = async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);
    if (!notification)
      return res.status(404).json({ message: "❌ Notification not found" });

    if (
      req.user.role !== "admin" &&
      String(notification.userId) !== String(req.user._id)
    ) {
      return res.status(403).json({ message: "🚫 Not allowed" });
    }

    await notification.deleteOne();

    res.status(200).json({
      message: "✅ Notification deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting notification",
      error: error.message,
    });
  }
};
