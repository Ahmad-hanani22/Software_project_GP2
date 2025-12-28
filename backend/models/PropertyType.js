// models/PropertyType.js
import mongoose from "mongoose";

const propertyTypeSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true, // apartment, house, villa, etc.
      index: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true, // Apartment, House, Villa, etc.
    },
    icon: {
      type: String,
      default: "home", // اسم الأيقونة في Flutter
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
propertyTypeSchema.index({ isActive: 1 });

const PropertyType = mongoose.model("PropertyType", propertyTypeSchema);

export default PropertyType;

