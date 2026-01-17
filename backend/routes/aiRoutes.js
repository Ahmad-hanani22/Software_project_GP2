// routes/aiRoutes.js
import express from "express";
import { chatWithAI, checkAIHealth, aiRecommend } from "../controllers/aiController.js";
import { protect } from "../Middleware/authMiddleware.js";
import { rateLimiter } from "../middleware/rateLimiter.js";

const router = express.Router();

/**
 * POST /api/ai/chat
 * محادثة مع AI (General questions about project)
 * Body: { question: string }
 * 
 * ✅ محمي بـ:
 * - Authentication (protect)
 * - Rate Limiting (10 requests/minute per user)
 */
router.post("/chat", protect, rateLimiter(10, 60 * 1000), chatWithAI);

/**
 * POST /api/ai/recommend
 * Chatbot with database integration (Smart System)
 * Body: { question: string, filters?: { budget?, city?, rooms?, type?, operation? } }
 * 
 * ✅ محمي بـ:
 * - Authentication (protect)
 * - Rate Limiting (15 requests/minute per user)
 */
router.post("/recommend", protect, rateLimiter(15, 60 * 1000), aiRecommend);

/**
 * GET /api/ai/health
 * فحص حالة AI Service
 */
router.get("/health", checkAIHealth);

export default router;
