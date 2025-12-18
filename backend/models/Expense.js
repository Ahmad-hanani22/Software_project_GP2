import mongoose from "mongoose";

const expenseSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
    },
    unitId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Unit",
    },
    type: {
      type: String,
      enum: ["maintenance", "tax", "utility", "management", "insurance", "other"],
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
    date: {
      type: Date,
      required: true,
    },
    description: {
      type: String,
    },
    receiptUrl: {
      type: String,
    },
    paidBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
    // للربط بالعقد إذا كانت المصروفات متعلقة بمستأجر معين
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
    },
  },
  { timestamps: true }
);

// Index
expenseSchema.index({ propertyId: 1, date: -1 });
expenseSchema.index({ unitId: 1, date: -1 });

const Expense = mongoose.model("Expense", expenseSchema);

export default Expense;

