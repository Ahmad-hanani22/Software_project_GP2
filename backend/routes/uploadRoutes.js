// routes/uploadRoutes.js
import express from "express";
import upload, { uploadToCloudinary } from "../middleware/uploadMiddleware.js";
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

router.post("/", protect, upload.single("image"), async (req, res) => {
  try {
    console.log("🟡 Upload endpoint hit!");
    if (!req.file) {
      console.log("❌ No image file received!");
      return res.status(400).json({ message: "❌ No image uploaded" });
    }

    console.log("📸 Uploading image to Cloudinary...");
    const result = await uploadToCloudinary(req.file.buffer);

    console.log("✅ Upload success:", result.secure_url);
    res.status(200).json({
      message: "✅ Image uploaded successfully",
      url: result.secure_url,
    });
  } catch (error) {
    console.error("❌ Error uploading image:", error);
    res.status(500).json({
      message: "❌ Error uploading image",
      error: error.message,
    });
  }
});

export default router;
