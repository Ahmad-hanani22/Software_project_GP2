import mongoose from "mongoose";

const unitSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      required: true,
    },
    unitNumber: {
      type: String,
      required: true,
    },
    floor: {
      type: Number,
      default: 0,
    },
    rooms: {
      type: Number,
      default: 0,
    },
    area: {
      type: Number, // بالمتر المربع
    },
    rentPrice: {
      type: Number,
      required: true,
    },
    status: {
      type: String,
      enum: ["vacant", "occupied", "reserved", "maintenance"],
      default: "vacant",
    },
    // معلومات إضافية
    bathrooms: {
      type: Number,
      default: 0,
    },
    description: {
      type: String,
    },
    images: [String],
    amenities: [String],
  },
  { timestamps: true }
);

// Index للتأكد من أن رقم الوحدة فريد لكل عقار
unitSchema.index({ propertyId: 1, unitNumber: 1 }, { unique: true });

const Unit = mongoose.model("Unit", unitSchema);

export default Unit;

