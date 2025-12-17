import Contract from "../models/Contract.js";
import { sendNotification } from "./sendNotification.js";

// 🔔 خدمة لتذكير بقرب انتهاء العقود (مثلاً تستدعيها من كرون job يومي)
export const notifyExpiringContracts = async () => {
  const now = new Date();

  const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const in7Days = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  // إيجاد العقود الفعالة التي تنتهي خلال 30 يوم
  const contracts = await Contract.find({
    status: { $in: ["active"] },
    endDate: { $gte: now, $lte: in30Days },
  });

  for (const contract of contracts) {
    const daysLeft = Math.ceil(
      (contract.endDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (daysLeft === 30 || daysLeft === 7) {
      await sendNotification({
        recipients: [contract.tenantId, contract.landlordId],
        title: "Contract Expiring Soon",
        message: `Your contract will expire in ${daysLeft} day(s).`,
        type: "contract",
        entityType: "contract",
        entityId: contract._id,
      });

      // تحديث حالة العقد إلى expiring_soon عند الاقتراب من الانتهاء
      contract.status = "expiring_soon";
      await contract.save();
    }
  }
};


