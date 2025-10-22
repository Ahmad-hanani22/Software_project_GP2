// middleware/uploadMiddleware.js
import multer from "multer";
import streamifier from "streamifier";
import cloudinary from "../utils/cloudinary.js";

const storage = multer.memoryStorage();
const upload = multer({ storage });


export const uploadToCloudinary = (fileBuffer) => {
  console.log("⚙️ uploadToCloudinary called...");
  return new Promise((resolve, reject) => {
    try {
      const stream = cloudinary.uploader.upload_stream(
        { folder: "real_estate_app" },
        (error, result) => {
          if (error) {
            console.error("❌ Cloudinary error:", error);
            return reject(error);
          }
          console.log("✅ Cloudinary upload complete!");
          resolve(result);
        }
      );
      streamifier.createReadStream(fileBuffer).pipe(stream);
    } catch (err) {
      console.error("❌ Unexpected error:", err);
      reject(err);
    }
  });
};


export default upload;
