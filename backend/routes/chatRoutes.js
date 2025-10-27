// routes/chatRoutes.js
import express from "express";
import {
  sendMessage,
  getConversation,
  getUserChats,
} from "../controllers/chatController.js";

import { protect, permitSelfOrAdmin } from "../Middleware/authMiddleware.js";

const router = express.Router();


router.post("/", protect, sendMessage);

router.get("/:user1/:user2", protect, getConversation);

دrouter.get("/user/:userId", protect, permitSelfOrAdmin("userId"), getUserChats);

export default router;
