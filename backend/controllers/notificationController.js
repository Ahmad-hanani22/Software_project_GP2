// controllers/notificationController.js

import Notification from "../models/Notification.js";
import User from "../models/User.js"; // استيراد User model
import { sendNotification } from "../utils/sendNotification.js"; // استيراد الدالة الرئيسية
import Contract from "../models/Contract.js"; // ✅ تأكد من استيراد Contract

// دالة لإنشاء وإرسال إشعار مخصص من الأدمن
export const createNotification = async (req, res) => {
  try {
    // recipients: 'all', 'tenants', 'landlords'
    const { recipients, message, title, type, link } = req.body;

    if (!recipients || !message) {
      return res.status(400).json({ message: "❌ Recipients and message are required" });
    }

    let userIds = [];
    if (recipients === 'all') {
      const users = await User.find({ role: { $ne: 'admin' } }).select('_id');
      userIds = users.map(u => u._id);
    } else if (recipients === 'tenants') {
      const users = await User.find({ role: 'tenant' }).select('_id');
      userIds = users.map(u => u._id);
    } else if (recipients === 'landlords') {
      const users = await User.find({ role: 'landlord' }).select('_id');
      userIds = users.map(u => u._id);
    } else {
        return res.status(400).json({ message: "Invalid recipients type" });
    }

    if (userIds.length === 0) {
        return res.status(404).json({ message: "No users found for the selected recipient group." });
    }

    // استخدام دالة الإرسال المركزية
    await sendNotification({
      recipients: userIds,
      message,
      title: title || 'A new message from Admin',
      type: type || 'system',
      link: link || '/',
      actorId: req.user._id, // الأدمن هو من قام بالفعل
    });

    res.status(200).json({
      message: `✅ Notification sent successfully to ${userIds.length} users.`,
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
      .populate("actorId", "name") // جلب اسم المرسل
      .sort({ createdAt: -1 });

    res.status(200).json(notifications);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching notifications",
      error: error.message,
    });
  }
};


// إرسال إشعار مباشر لمستخدم محدد (مثلاً من مستأجر لمالك)
export const sendDirectNotification = async (req, res) => {
  try {
    const { recipientId, title, message, type } = req.body;

    if (!recipientId || !message) {
      return res.status(400).json({ message: "Recipient ID and message are required" });
    }

    await sendNotification({
      recipients: [recipientId], 
      message,
      title: title || 'New Notification',
      type: type || 'system',
      actorId: req.user._id, 
    });

    res.status(200).json({ message: "Notification sent successfully" });
  } catch (error) {
    res.status(500).json({ message: "Error sending notification", error: error.message });
  }
};




export const getUserNotifications = async (req, res) => {
  try {
    const { userId } = req.params;

    // 1️⃣ الفحص الذكي: هل يوجد عقود تنتهي خلال 7 أيام؟
    const today = new Date();
    const nextWeek = new Date();
    nextWeek.setDate(today.getDate() + 7);

    // ابحث عن عقود نشطة، تنتهي قريباً، وتخص هذا المستخدم
    const expiringContracts = await Contract.find({
      tenantId: userId,
      status: { $in: ["active", "rented"] }, // الحالات النشطة
      endDate: { $lte: nextWeek, $gte: today } // تاريخ الانتهاء بين اليوم والأسبوع القادم
    });

    // لكل عقد ينتهي، تحقق هل أرسلنا إشعاراً مسبقاً؟ إذا لا، أنشئ واحداً
    for (const contract of expiringContracts) {
      const daysLeft = Math.ceil((contract.endDate - today) / (1000 * 60 * 60 * 24));
      
      const msg = `⚠️ تنبيه: عقدك للعقار ينتهي خلال ${daysLeft} أيام. يرجى التجديد أو التواصل مع المالك.`;

      // تحقق لعدم تكرار الإشعار لنفس العقد في نفس اليوم
      const alreadyNotified = await Notification.findOne({
        userId: userId,
        entityId: contract._id,
        type: "contract_expiry",
        createdAt: { $gte: new Date(new Date().setHours(0,0,0,0)) } // إشعار واحد يومياً
      });

      if (!alreadyNotified) {
        await Notification.create({
          userId: userId,
          message: msg,
          type: "contract_expiry", // نوع جديد للإشعارات
          entityType: "contract",
          entityId: contract._id,
          isRead: false
        });
        console.log(`🔔 Notification created for contract ${contract._id}`);
      }
    }

    // 2️⃣ الآن جلب الإشعارات كالمعتاد
    const notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 })
      .limit(50); 

    res.status(200).json(notifications);
  } catch (error) {
    console.error("Error in getUserNotifications:", error);
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
