import mongoose from "mongoose";

const invoiceSchema = new mongoose.Schema(
  {
    paymentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Payment",
      required: true,
    },
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
      required: true,
    },
    invoiceNumber: {
      type: String,
      required: true,
      unique: true,
    },
    pdfUrl: {
      type: String,
    },
    issuedAt: {
      type: Date,
      default: Date.now,
    },
    dueDate: {
      type: Date,
    },
    // معلومات إضافية
    items: [
      {
        description: String,
        quantity: Number,
        unitPrice: Number,
        total: Number,
      },
    ],
    subtotal: Number,
    tax: Number,
    total: Number,
  },
  { timestamps: true }
);

// Index
invoiceSchema.index({ contractId: 1, issuedAt: -1 });


// Generate invoice number قبل الحفظ
invoiceSchema.pre("save", async function (next) {
  if (!this.invoiceNumber) {
    try {
      const InvoiceModel = mongoose.model("Invoice");
      const count = await InvoiceModel.countDocuments();
      this.invoiceNumber = `INV-${Date.now()}-${count + 1}`;
    } catch (error) {
      // في حالة عدم وجود النموذج بعد (أثناء التهيئة)
      if (error.name !== 'MissingSchemaError') {
        return next(error);
      }
      this.invoiceNumber = `INV-${Date.now()}-1`;
    }
  }
  next();
});

const Invoice = mongoose.model("Invoice", invoiceSchema);

export default Invoice;

