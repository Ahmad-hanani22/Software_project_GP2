import mongoose from "mongoose";

const buildingSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
    },
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    address: {
      type: String,
      required: true,
    },
    city: {
      type: String,
    },
    country: {
      type: String,
    },
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: {
        type: [Number], // [longitude, latitude]
      },
    },
    totalFloors: {
      type: Number,
      default: 1,
    },
    totalUnits: {
      type: Number,
      default: 0,
    },
    description: {
      type: String,
    },
    images: [String],
    amenities: [String],
    // معلومات إدارية
    managementCompany: {
      type: String,
    },
    yearBuilt: {
      type: Number,
    },
  },
  { timestamps: true }
);

// Index
buildingSchema.index({ location: "2dsphere" });
buildingSchema.index({ ownerId: 1 });

const Building = mongoose.model("Building", buildingSchema);

export default Building;

