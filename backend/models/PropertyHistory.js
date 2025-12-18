import mongoose from "mongoose";

const propertyHistorySchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      required: true,
    },
    action: {
      type: String,
      enum: [
        "created",
        "updated",
        "deleted",
        "status_changed",
        "price_changed",
        "verified",
        "unit_added",
        "unit_removed",
        "contract_added",
        "contract_removed",
      ],
      required: true,
    },
    performedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    changes: {
      type: mongoose.Schema.Types.Mixed, // لتخزين التغييرات
    },
    description: {
      type: String,
    },
  },
  { timestamps: true }
);

// Index
propertyHistorySchema.index({ propertyId: 1, createdAt: -1 });
propertyHistorySchema.index({ performedBy: 1 });

const PropertyHistory = mongoose.model("PropertyHistory", propertyHistorySchema);

export default PropertyHistory;

