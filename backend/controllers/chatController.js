import Chat from "../models/Chat.js";
import { sendNotification } from "../utils/sendNotification.js";

export const sendMessage = async (req, res) => {
  try {
    const { receiverId, propertyId, message, attachments } = req.body;

    if (!receiverId || !message) {
      return res
        .status(400)
        .json({ message: "❌ receiverId and message are required" });
    }

    const senderId = req.user._id;

    const newMessage = new Chat({
      senderId,
      receiverId,
      propertyId,
      message,
      attachments,
    });

    await newMessage.save();

    await sendNotification({
      userId: receiverId,
      message: `📩 رسالة جديدة من ${req.user.name}: "${message.substring(
        0,
        30
      )}"`,
      type: "chat",
      actorId: senderId,
      entityType: "chat",
      entityId: newMessage._id,
    });

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
