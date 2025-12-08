// routes/chatRoutes.js
import express from "express";
import {
  sendMessage,
  getConversation,
  getUserChats,
} from "../controllers/chatController.js";

import { protect, permitSelfOrAdmin } from "../Middleware/authMiddleware.js";
import { markAsRead } from "../controllers/chatController.js";

const router = express.Router();


router.post("/", protect, sendMessage);

router.get("/:user1/:user2", protect, getConversation);

router.get("/user/:userId", protect, permitSelfOrAdmin("userId"), getUserChats);
router.put("/read", protect, markAsRead);

export default router;
