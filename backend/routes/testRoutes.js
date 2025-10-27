import express from "express";
import { protect } from "../Middleware/authMiddleware.js";

const router = express.Router();

router.get("/check", protect, (req, res) => {
  res.json({
    message: "✅ Token verified successfully!",
    user: req.user, 
  });
});

export default router;
