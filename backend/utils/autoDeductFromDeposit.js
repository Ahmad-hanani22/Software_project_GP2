import Payment from "../models/Payment.js";
import Deposit from "../models/Deposit.js";
import Contract from "../models/Contract.js";
import { sendNotificationToUser } from "./sendNotification.js";

/**
 * خصم تلقائي من الـ deposit عند مجيء موعد الدفعة
 * يتم استدعاء هذه الوظيفة يومياً من cron job أو عند إنشاء payment جديد
 */
export async function autoDeductFromDepositForDuePayments() {
  try {
    const now = new Date();
    // جلب جميع الدفعات المستحقة (pending) التي وصل موعدها
    const duePayments = await Payment.find({
      status: "pending",
      date: { $lte: now }, // موعد الدفعة قد حان أو تجاوز
    }).populate("contractId");

    console.log(`🔍 Found ${duePayments.length} due payments to process`);

    let processedCount = 0;
    let deductedCount = 0;

    for (const payment of duePayments) {
      try {
        const contract = payment.contractId;
        if (!contract) {
          console.warn(`⚠️ Payment ${payment._id} has no contract`);
          continue;
        }

        // جلب الـ deposit للعقد
        const deposit = await Deposit.findOne({ contractId: contract._id });
        if (!deposit) {
          console.log(`ℹ️ No deposit found for contract ${contract._id}, skipping payment ${payment._id}`);
          continue;
        }

        // التحقق من أن الـ deposit لا يزال محتفظ به (held) وليس مسترد
        if (deposit.status === "refunded") {
          console.log(`ℹ️ Deposit for contract ${contract._id} is already refunded, skipping payment ${payment._id}`);
          continue;
        }

        // حساب المبلغ المتاح للخصم
        const availableAmount = deposit.amount - (deposit.totalDeducted || 0) - (deposit.refundedAmount || 0);
        
        if (availableAmount <= 0) {
          console.log(`ℹ️ No available deposit amount for contract ${contract._id}, skipping payment ${payment._id}`);
          continue;
        }

        // خصم مبلغ الدفعة من الـ deposit (أو المبلغ المتاح إذا كان أقل)
        const deductionAmount = Math.min(payment.amount, availableAmount);

        // إضافة خصم جديد
        deposit.deductions.push({
          amount: deductionAmount,
          reason: `Auto-deduction for payment due on ${payment.date.toISOString().split('T')[0]}`,
          deductedAt: new Date(),
        });

        deposit.totalDeducted = (deposit.totalDeducted || 0) + deductionAmount;

        // تحديث حالة الـ deposit إذا تم خصم كل المبلغ
        if (deposit.totalDeducted >= deposit.amount) {
          deposit.status = "partially_refunded"; // أو يمكن تغييره حسب منطقك
        }

        await deposit.save();

        // تحديث حالة الدفعة إلى paid إذا تم خصم المبلغ الكامل
        if (deductionAmount >= payment.amount) {
          payment.status = "paid";
          payment.method = "deposit_deduction"; // إضافة طريقة دفع جديدة
          await payment.save();
          deductedCount++;

          // إشعار للمستأجر
          await sendNotificationToUser({
            userId: contract.tenantId,
            title: "💰 خصم تلقائي من الوديعة",
            message: `تم خصم مبلغ \$${deductionAmount} من وديعتك لدفع الإيجار المستحق`,
            type: "payment",
            actorId: null, // تلقائي
            entityType: "payment",
            entityId: payment._id,
            link: `/payments/${payment._id}`,
          });

          // إشعار للمالك
          await sendNotificationToUser({
            userId: contract.landlordId,
            title: "💰 خصم تلقائي من الوديعة",
            message: `تم خصم مبلغ \$${deductionAmount} من ودائع المستأجر لدفع الإيجار المستحق`,
            type: "payment",
            actorId: null, // تلقائي
            entityType: "payment",
            entityId: payment._id,
            link: `/payments/${payment._id}`,
          });

          console.log(`✅ Auto-deducted $${deductionAmount} from deposit for payment ${payment._id}`);
        } else {
          // إذا لم يكف المبلغ، نخصم ما هو متاح ونترك الدفعة pending
          console.log(`⚠️ Partial deduction: $${deductionAmount} from deposit (payment amount: $${payment.amount}) for payment ${payment._id}`);
          
          // إشعار للمستأجر بأن هناك خصم جزئي
          await sendNotificationToUser({
            userId: contract.tenantId,
            title: "⚠️ خصم جزئي من الوديعة",
            message: `تم خصم مبلغ \$${deductionAmount} من وديعتك (المبلغ المطلوب: \$${payment.amount}). يرجى دفع الفرق`,
            type: "payment",
            actorId: null,
            entityType: "payment",
            entityId: payment._id,
            link: `/payments/${payment._id}`,
          });
        }

        processedCount++;
      } catch (error) {
        console.error(`❌ Error processing payment ${payment._id}:`, error);
        // نستمر في معالجة الدفعات الأخرى حتى لو فشلت واحدة
      }
    }

    console.log(`✅ Auto-deduction completed: ${processedCount} payments processed, ${deductedCount} fully deducted`);
    return { processedCount, deductedCount };
  } catch (error) {
    console.error("❌ Error in autoDeductFromDepositForDuePayments:", error);
    throw error;
  }
}

/**
 * خصم تلقائي لدفعة معينة (يتم استدعاؤها عند إنشاء payment جديد)
 */
export async function checkAndDeductForPayment(paymentId) {
  try {
    const payment = await Payment.findById(paymentId).populate("contractId");
    if (!payment) {
      console.warn(`⚠️ Payment ${paymentId} not found`);
      return;
    }

    // التحقق من أن الدفعة pending وموعدها قد حان
    if (payment.status !== "pending") {
      return;
    }

    const now = new Date();
    const paymentDate = new Date(payment.date);
    
    // إذا لم يحن موعد الدفعة بعد، لا نفعل شيء
    if (paymentDate > now) {
      return;
    }

    const contract = payment.contractId;
    if (!contract) {
      return;
    }

    // جلب الـ deposit
    const deposit = await Deposit.findOne({ contractId: contract._id });
    if (!deposit || deposit.status === "refunded") {
      return;
    }

    // حساب المبلغ المتاح
    const availableAmount = deposit.amount - (deposit.totalDeducted || 0) - (deposit.refundedAmount || 0);
    
    if (availableAmount <= 0) {
      return;
    }

    // خصم المبلغ
    const deductionAmount = Math.min(payment.amount, availableAmount);

    deposit.deductions.push({
      amount: deductionAmount,
      reason: `Auto-deduction for payment due on ${payment.date.toISOString().split('T')[0]}`,
      deductedAt: new Date(),
    });

    deposit.totalDeducted = (deposit.totalDeducted || 0) + deductionAmount;

    if (deposit.totalDeducted >= deposit.amount) {
      deposit.status = "partially_refunded";
    }

    await deposit.save();

    // إذا تم خصم المبلغ الكامل، تحديث حالة الدفعة
    if (deductionAmount >= payment.amount) {
      payment.status = "paid";
      payment.method = "deposit_deduction";
      await payment.save();

      // إشعارات
      await sendNotificationToUser({
        userId: contract.tenantId,
        title: "💰 خصم تلقائي من الوديعة",
        message: `تم خصم مبلغ \$${deductionAmount} من وديعتك لدفع الإيجار المستحق`,
        type: "payment",
        actorId: null,
        entityType: "payment",
        entityId: payment._id,
        link: `/payments/${payment._id}`,
      });

      await sendNotificationToUser({
        userId: contract.landlordId,
        title: "💰 خصم تلقائي من الوديعة",
        message: `تم خصم مبلغ \$${deductionAmount} من ودائع المستأجر لدفع الإيجار المستحق`,
        type: "payment",
        actorId: null,
        entityType: "payment",
        entityId: payment._id,
        link: `/payments/${payment._id}`,
      });

      console.log(`✅ Auto-deducted $${deductionAmount} from deposit for payment ${payment._id}`);
    }

    return { deducted: deductionAmount >= payment.amount, deductionAmount };
  } catch (error) {
    console.error(`❌ Error in checkAndDeductForPayment for payment ${paymentId}:`, error);
    throw error;
  }
}
