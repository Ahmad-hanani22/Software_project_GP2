// models/Amenity.js
import mongoose from "mongoose";

const amenitySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true, // wifi, parking, pool, etc.
      index: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true, // Wifi, Parking, Pool, etc.
    },
    icon: {
      type: String,
      default: "check_circle", // اسم الأيقونة في Flutter
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    order: {
      type: Number,
      default: 0, // للترتيب في الواجهة
    },
    description: {
      type: String,
    },
  },
  { timestamps: true }
);

// Index للبحث السريع
amenitySchema.index({ isActive: 1 });

const Amenity = mongoose.model("Amenity", amenitySchema);

export default Amenity;
