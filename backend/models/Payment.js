import mongoose from "mongoose";

const paymentSchema = new mongoose.Schema(
  {
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
      required: true,
    },
    amount: Number,
    method: { type: String, enum: ["cash", "bank", "online"] },
    status: {
      type: String,
      enum: ["pending", "paid", "failed"],
      default: "pending",
    },
    date: Date,
    receiptUrl: String,
  },
  { timestamps: true }
);

export default mongoose.model("Payment", paymentSchema);
