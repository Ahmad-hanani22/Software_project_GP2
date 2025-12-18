import mongoose from "mongoose";

const depositSchema = new mongoose.Schema(
  {
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
      required: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    currency: {
      type: String,
      default: "USD",
    },
    status: {
      type: String,
      enum: ["held", "partially_refunded", "refunded"],
      default: "held",
    },
    deductions: [
      {
        amount: Number,
        reason: String,
        deductedAt: Date,
      },
    ],
    totalDeducted: {
      type: Number,
      default: 0,
    },
    refundedAmount: {
      type: Number,
      default: 0,
    },
    receivedAt: {
      type: Date,
      default: Date.now,
    },
    refundedAt: {
      type: Date,
    },
    notes: {
      type: String,
    },
  },
  { timestamps: true }
);

// Index
depositSchema.index({ contractId: 1 });

const Deposit = mongoose.model("Deposit", depositSchema);

export default Deposit;

