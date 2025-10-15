// middleware/uploadMiddleware.js
import multer from "multer";
import streamifier from "streamifier";
import cloudinary from "../utils/cloudinary.js";

const storage = multer.memoryStorage();
const upload = multer({ storage });

// ✅ Middleware جاهز للرفع إلى Cloudinary
export const uploadToCloudinary = async (fileBuffer) => {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: "real_estate_app" },
      (error, result) => {
        if (error) reject(error);
        else resolve(result);
      }
    );
    streamifier.createReadStream(fileBuffer).pipe(stream);
  });
};

export default upload;
