import Payment from "../models/Payment.js";

// Ensure there is at least ONE upcoming payment for a contract.
// We DO NOT create the whole schedule here anymore to avoid flooding
// the system with many future payments.
export async function ensurePaymentPlanForContract(contract) {
  try {
    if (!contract) return;
    if (contract.status !== "active" && contract.status !== "rented") {
      return;
    }

    const rentAmount = contract.rentAmount || 0;
    if (!rentAmount || !contract.startDate || !contract.endDate) {
      return;
    }

    const existingPayments = await Payment.find({
      contractId: contract._id,
    }).sort({ date: 1 });

    // If there is already at least one payment (pending or paid), we do nothing.
    if (existingPayments.length > 0) {
      return;
    }

    const start = new Date(contract.startDate);

    // Create ONLY the first payment (initial installment)
    await Payment.create({
      contractId: contract._id,
      amount: rentAmount,
      method: "bank",
      status: "pending",
      date: start,
    });

    console.log(
      `✅ Initial payment created for contract ${contract._id} on ${start.toISOString()}`
    );
  } catch (error) {
    console.error(
      `⚠️ Error ensuring payment plan for contract ${contract?._id}:`,
      error
    );
  }
}

