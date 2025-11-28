import mongoose from "mongoose";

const contractSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      required: true,
    },
    tenantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    landlordId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    startDate: Date,
    endDate: Date,
    rentAmount: Number,
    paymentCycle: {
      type: String,
      enum: ["monthly", "quarterly", "yearly"],
      default: "monthly",
    },
    status: {
      type: String,
      enum: ["active", "terminated", "expired", "pending", "rejected"], 
      default: "pending", // يفضل جعل الافتراضي pending
    },
    pdfUrl: String,
  },
  { timestamps: true }
);

export default mongoose.model("Contract", contractSchema);
