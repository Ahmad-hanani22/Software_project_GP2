import mongoose from "mongoose";

const propertySchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    title: String,
    description: String,
    type: { type: String, required: true }, // ديناميكي - يتم التحقق من وجوده في PropertyType
    operation: { type: String, enum: ["rent", "sale"] },
    price: Number,
    currency: { type: String, default: "USD" },
    country: String,
    city: String,
    address: String,
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: {
        type: [Number], // [longitude, latitude]
        required: true,
      },
    },
    area: Number,
    bedrooms: Number,
    bathrooms: Number,
    amenities: [String],
    images: [String],
    model3dUrl: String, // 3D model URL for property visualization
    status: {
      type: String,
      enum: ["available", "rented", "pending_approval"],
      default: "pending_approval",
    },
    verified: { type: Boolean, default: false },
    // ✅ معلومات العمارات (Apartment-specific)
    buildingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Building",
      default: null, // اختياري - إذا كان العقار جزء من مبنى
    },
    totalUnits: {
      type: Number,
      default: 0, // عدد الشقق في العمارة
    },
    displayedUnits: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: "Unit",
    }], // الشقق المحددة للعرض
    unitsDisplayMode: {
      type: String,
      enum: ["all", "selected", "available"], // all: كل الشقق، selected: المحددة، available: المتاحة فقط
      default: "all",
    },
  },
  { timestamps: true }
);

// ✅ ضع الـ index على location فقط
propertySchema.index({ location: "2dsphere" });

const Property = mongoose.model("Property", propertySchema);

export default Property;
