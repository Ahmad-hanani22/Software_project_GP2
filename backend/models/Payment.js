import mongoose from "mongoose";

const paymentSchema = new mongoose.Schema(
  {
    contractId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Contract",
      required: true,
    },
    amount: Number,
    method: { type: String, enum: ["cash", "bank", "online", "visa", "test_visa", "deposit_deduction"] },
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
  // Flag to know if status has just changed to "paid"
  this._statusChangedToPaid =
    this.isModified("status") && this.status === "paid";

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

// After a payment is created or updated, check if it's due and auto-deduct from deposit
paymentSchema.post("save", async function (doc, next) {
  try {
    // ✅ التحقق من موعد الدفعة وخصم تلقائي من الـ deposit إذا لزم الأمر
    // فقط للدفعات الجديدة أو المحدثة التي هي pending
    if (doc.status === "pending" && doc.isNew) {
      try {
        const { checkAndDeductForPayment } = await import("../utils/autoDeductFromDeposit.js");
        // نستخدم setTimeout لتأخير التحقق قليلاً
        setTimeout(async () => {
          try {
            await checkAndDeductForPayment(doc._id);
          } catch (error) {
            console.error("Error in auto-deduction check for new payment:", error);
          }
        }, 1000);
      } catch (error) {
        console.error("Error importing autoDeductFromDeposit:", error);
      }
    }

    // ✅ إنشاء الدفعة التالية عند دفع الدفعة الحالية
    if (!this._statusChangedToPaid) return next();

    const Contract = mongoose.model("Contract");
    const PaymentModel = mongoose.model("Payment");

    const contract = await Contract.findById(doc.contractId);
    if (!contract) return next();

    if (contract.status !== "active" && contract.status !== "rented") {
      return next();
    }

    const cycle = (contract.paymentCycle || "monthly").toLowerCase();
    const baseDate = doc.date || new Date();
    let nextDate;

    if (cycle === "daily") {
      nextDate = new Date(
        baseDate.getFullYear(),
        baseDate.getMonth(),
        baseDate.getDate() + 1
      );
    } else if (cycle === "weekly") {
      nextDate = new Date(
        baseDate.getFullYear(),
        baseDate.getMonth(),
        baseDate.getDate() + 7
      );
    } else {
      let monthStep = 1;
      if (cycle === "quarterly") monthStep = 3;
      if (cycle === "yearly") monthStep = 12;
      nextDate = new Date(
        baseDate.getFullYear(),
        baseDate.getMonth() + monthStep,
        baseDate.getDate()
      );
    }

    // Do not create beyond contract endDate
    if (contract.endDate && nextDate > contract.endDate) {
      return next();
    }

    // If there is already a pending payment on or after nextDate, skip
    const existingPending = await PaymentModel.findOne({
      contractId: contract._id,
      status: "pending",
      date: { $gte: nextDate },
    });

    if (existingPending) {
      return next();
    }

    const nextPayment = await PaymentModel.create({
      contractId: contract._id,
      amount: doc.amount,
      method: "bank",
      status: "pending",
      date: nextDate,
    });

    // ✅ التحقق من موعد الدفعة الجديدة وخصم تلقائي من الـ deposit إذا لزم الأمر
    try {
      const { checkAndDeductForPayment } = await import("../utils/autoDeductFromDeposit.js");
      // نستخدم setTimeout لتأخير التحقق قليلاً للتأكد من أن الدفعة تم حفظها
      setTimeout(async () => {
        try {
          await checkAndDeductForPayment(nextPayment._id);
        } catch (error) {
          console.error("Error in auto-deduction check for new payment:", error);
        }
      }, 1000);
    } catch (error) {
      console.error("Error importing autoDeductFromDeposit:", error);
    }

    return next();
  } catch (err) {
    console.error("Error creating next installment payment:", err);
    return next(err);
  }
});

export default mongoose.model("Payment", paymentSchema);
