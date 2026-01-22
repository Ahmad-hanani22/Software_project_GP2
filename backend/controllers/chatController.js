// controllers/chatController.js

import Chat from "../models/Chat.js";
import User from "../models/User.js";
import { sendNotificationToUser } from "../utils/sendNotification.js";

/* ========================================================
   Send Message
======================================================== */
export const sendMessage = async (req, res) => {
  try {
    const { receiverId, propertyId, message, attachments } = req.body;

    if (!receiverId || !message) {
      return res
        .status(400)
        .json({ message: "❌ receiverId and message are required" });
    }

    const senderId = req.user._id;

    // Get sender name for notification
    const sender = await User.findById(senderId).select("name").lean();
    const senderName = sender?.name || "Someone";

    const newMessage = new Chat({
      senderId,
      receiverId,
      propertyId,
      message,
      attachments,
      isRead: false, // افتراضياً غير مقروءة
    });

    await newMessage.save();

    // 1. Socket.IO: إرسال للمستقبل
    req.io.to(receiverId).emit("receive_message", newMessage);
    
    // 2. Socket.IO: إرسال للمرسل (تأكيد)
    req.io.to(String(senderId)).emit("message_sent", newMessage);
    
    // 3. ✅ إرسال إشعار Push Notification للمستقبل
    try {
      await sendNotificationToUser({
        userId: receiverId,
        title: `💬 New message from ${senderName}`,
        message: message.length > 100 ? message.substring(0, 100) + "..." : message,
        type: "message",
        actorId: senderId,
        entityType: "chat",
        entityId: newMessage._id,
        link: `/chat/${senderId}`,
      });
    } catch (notifError) {
      // لا نفشل العملية إذا فشل الإشعار
      console.warn("⚠️ Failed to send message notification:", notifError.message);
    }

    res.status(201).json({
      message: "✅ Message sent successfully",
      data: newMessage,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error sending message", error: error.message });
  }
};

/* ========================================================
   Get Conversation between two users
======================================================== */
export const getConversation = async (req, res) => {
  try {
    const { user1, user2 } = req.params;

    if (
      req.user.role !== "admin" &&
      req.user._id.toString() !== user1 &&
      req.user._id.toString() !== user2
    ) {
      return res
        .status(403)
        .json({ message: "🚫 Access denied to this conversation" });
    }

    const messages = await Chat.find({
      $or: [
        { senderId: user1, receiverId: user2 },
        { senderId: user2, receiverId: user1 },
      ],
    }).sort({ createdAt: 1 });

    res.status(200).json(messages);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching conversation",
      error: error.message,
    });
  }
};

/* ========================================================
   Get User Chats (Inbox Summary)
======================================================== */
export const getUserChats = async (req, res) => {
  try {
    const { userId } = req.params;

    if (req.user.role !== "admin" && req.user._id.toString() !== userId) {
      return res.status(403).json({ message: "🚫 Access denied to inbox" });
    }

    const chats = await Chat.aggregate([
      {
        $match: {
          $or: [{ senderId: userId }, { receiverId: userId }],
        },
      },
      {
        $group: {
          _id: {
            sender: "$senderId",
            receiver: "$receiverId",
          },
          lastMessage: { $last: "$message" },
          lastDate: { $last: "$createdAt" },
        },
      },
      { $sort: { lastDate: -1 } },
    ]);

    res.status(200).json(chats);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching user chats", error: error.message });
  }
};

/* ========================================================
   ✅ Mark Messages as Read
   هذه الدالة الجديدة لتصفير العداد الأحمر
======================================================== */
export const markAsRead = async (req, res) => {
  try {
    const { senderId } = req.body; // الشخص الذي أقرأ رسائله الآن (الطرف الآخر)
    const receiverId = req.user._id; // أنا (المستقبل)

    // تحديث كل الرسائل القادمة من senderId والمرسلة لي، والتي حالتها غير مقروءة
    await Chat.updateMany(
      { senderId: senderId, receiverId: receiverId, isRead: false },
      { $set: { isRead: true } }
    );

    res.status(200).json({ message: "✅ Messages marked as read" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};