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
    type: { type: String, enum: ["apartment", "house", "villa", "shop"] },
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
    status: {
      type: String,
      enum: ["available", "rented", "pending_approval"],
      default: "pending_approval",
    },
    verified: { type: Boolean, default: false },
  },
  { timestamps: true }
);

// ✅ ضع الـ index على location فقط
propertySchema.index({ location: "2dsphere" });

const Property = mongoose.model("Property", propertySchema);

export default Property;
