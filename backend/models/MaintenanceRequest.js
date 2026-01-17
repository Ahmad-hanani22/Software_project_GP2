import mongoose from "mongoose";

const maintenanceSchema = new mongoose.Schema(
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
    description: String,
    type: {
      type: String,
      enum: ["maintenance", "complaint"],
      default: "maintenance",
    },
    status: {
      type: String,
      enum: ["pending", "in_progress", "resolved"],
      default: "pending",
    },
    technicianName: String,
    images: [String],
  },
  { timestamps: true }
);

export default mongoose.model("MaintenanceRequest", maintenanceSchema);
