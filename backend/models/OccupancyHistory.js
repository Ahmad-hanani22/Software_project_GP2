import mongoose from "mongoose";

const occupancyHistorySchema = new mongoose.Schema(
  {
    unitId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Unit",
      required: true,
    },
    tenantId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
    },
    from: {
      type: Date,
      required: true,
    },
    to: {
      type: Date, // null يعني لا يزال مشغول
    },
    notes: {
      type: String,
    },
  },
  { timestamps: true }
);

// Index لتحسين الاستعلامات
occupancyHistorySchema.index({ unitId: 1, from: -1 });
occupancyHistorySchema.index({ tenantId: 1 });

const OccupancyHistory = mongoose.model("OccupancyHistory", occupancyHistorySchema);

export default OccupancyHistory;

