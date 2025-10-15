// routes/uploadRoutes.js
import express from "express";
import upload, { uploadToCloudinary } from "../Middleware/uploadMiddleware.js";
import { protect } from "../Middleware/authMiddleware.js";

const router = express.Router();

// 🖼️ رفع صورة عامة لأي نوع (Property / Maintenance / Profile...)
router.post("/", protect, upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "❌ No image uploaded" });
    }

    const result = await uploadToCloudinary(req.file.buffer);

    res.status(200).json({
      message: "✅ Image uploaded successfully",
      url: result.secure_url,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error uploading image",
      error: error.message,
    });
  }
});

export default router;
