import mongoose from "mongoose";

const paymentSchema = new mongoose.Schema(
  {
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
      required: true,
    },
    amount: Number,
    method: { type: String, enum: ["cash", "bank", "online", "visa", "test_visa"] },
    status: {
      type: String,
      enum: ["pending", "paid", "failed"],
      default: "pending",
    },
    date: Date,
    receiptUrl: String,
    // ✅ سند القبض (Payment Receipt)
    receipt: {
      receiptNumber: { type: String, unique: true, sparse: true },
      receiptDate: Date,
      receiptTime: String, // Time as string (HH:mm)
      issuedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // Admin/Landlord who issued the receipt
      paymentMethod: String,
      referenceNumber: String, // Transaction reference number
      notes: String,
      pdfUrl: String, // PDF version of receipt
    },
  },
  { timestamps: true }
);

// Generate receipt number before saving (only when status becomes 'paid')
paymentSchema.pre("save", async function (next) {
  if (this.isModified("status") && this.status === "paid" && !this.receipt?.receiptNumber) {
    try {
      const PaymentModel = mongoose.model("Payment");
      const count = await PaymentModel.countDocuments({ status: "paid" });
      this.receipt = this.receipt || {};
      this.receipt.receiptNumber = `REC-${Date.now()}-${count + 1}`;
      if (!this.receipt.receiptDate) {
        this.receipt.receiptDate = new Date();
      }
      if (!this.receipt.receiptTime) {
        const now = new Date();
        this.receipt.receiptTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
      }
    } catch (error) {
      return next(error);
    }
  }
  next();
});

export default mongoose.model("Payment", paymentSchema);
