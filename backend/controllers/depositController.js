import Deposit from "../models/Deposit.js";
import Contract from "../models/Contract.js";
import { sendNotification } from "../utils/sendNotification.js";

// 1. إضافة تأمين
export const addDeposit = async (req, res) => {
  try {
    const { contractId, amount } = req.body;

    const contract = await Contract.findById(contractId);
    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    // التحقق من الصلاحيات (مالك، أدمن، أو مستأجر للعقد)
    const isLandlord = String(contract.landlordId) === String(req.user._id);
    const isTenant = String(contract.tenantId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";
    
    if (!isLandlord && !isAdmin && !isTenant) {
      return res.status(403).json({
        message: "You are not authorized to add deposit for this contract",
      });
    }
    
    // المستأجر يمكنه فقط إضافة وديعة للعقد النشط (active) فقط
    if (isTenant && contract.status !== "active") {
      return res.status(400).json({
        message: "You can only add deposit for active contracts",
      });
    }

    // التحقق من عدم وجود تأمين موجود
    const existingDeposit = await Deposit.findOne({ contractId });
    if (existingDeposit) {
      return res.status(400).json({
        message: "Deposit already exists for this contract",
      });
    }

    // إذا كان هناك depositAmount في العقد، يمكن استخدامه كمرجع
    // لكن المستأجر يمكنه دفع مبلغ مختلف إذا اتفق مع المالك
    const deposit = new Deposit({
      contractId,
      amount,
      currency: req.body.currency || "USD",
      status: "held",
    });
    await deposit.save();

    // إشعار للمستأجر (إذا لم يكن هو من أضافها)
    if (!isTenant) {
      await sendNotification({
        recipients: [contract.tenantId],
        message: `💰 تأمين بقيمة ${amount} تم استلامه`,
        title: "Deposit Received",
        type: "deposit",
        actorId: req.user._id,
        entityType: "deposit",
        entityId: deposit._id,
      });
    }
    
    // إشعار للمالك (إذا كان المستأجر هو من أضافها)
    if (isTenant) {
      await sendNotification({
        recipients: [contract.landlordId],
        message: `💰 مستأجر أضاف وديعة بقيمة ${amount} للعقد`,
        title: "Deposit Added by Tenant",
        type: "deposit",
        actorId: req.user._id,
        entityType: "deposit",
        entityId: deposit._id,
      });
    }

    res.status(201).json({
      message: "✅ Deposit added successfully",
      deposit,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error adding deposit",
      error: error.message,
    });
  }
};

// 2. جلب تأمين عقد معين
export const getDepositByContract = async (req, res) => {
  try {
    const { contractId } = req.params;
    const deposit = await Deposit.findOne({ contractId }).populate(
      "contractId",
      "tenantId landlordId"
    );

    if (!deposit) {
      return res.status(404).json({ message: "Deposit not found" });
    }

    res.status(200).json(deposit);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching deposit",
      error: error.message,
    });
  }
};

// 3. تحديث تأمين (استقطاع أو استرداد)
export const updateDeposit = async (req, res) => {
  try {
    const deposit = await Deposit.findById(req.params.id);
    if (!deposit) {
      return res.status(404).json({ message: "Deposit not found" });
    }

    const contract = await Contract.findById(deposit.contractId);
    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    // التحقق من الصلاحيات (مالك، أدمن، أو مستأجر للعقد)
    const isLandlord = String(contract.landlordId) === String(req.user._id);
    const isTenant = String(contract.tenantId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";
    
    if (!isLandlord && !isAdmin && !isTenant) {
      return res.status(403).json({
        message: "You are not authorized to update this deposit",
      });
    }

    // معالجة الاستقطاع
    if (req.body.deduction) {
      const { amount, reason } = req.body.deduction;
      deposit.deductions.push({
        amount,
        reason,
        deductedAt: new Date(),
      });
      deposit.totalDeducted = (deposit.totalDeducted || 0) + amount;
    }

    // معالجة الاسترداد
    if (req.body.refundAmount) {
      const refundAmount = req.body.refundAmount;
      const availableAmount = deposit.amount - (deposit.totalDeducted || 0);

      if (refundAmount > availableAmount) {
        return res.status(400).json({
          message: "Refund amount exceeds available deposit",
        });
      }

      deposit.refundedAmount = (deposit.refundedAmount || 0) + refundAmount;

      if (deposit.refundedAmount >= deposit.amount - (deposit.totalDeducted || 0)) {
        deposit.status = "refunded";
        deposit.refundedAt = new Date();
      } else if (deposit.refundedAmount > 0) {
        deposit.status = "partially_refunded";
        deposit.refundedAt = new Date();
      }
    }

    if (req.body.status) {
      deposit.status = req.body.status;
    }

    await deposit.save();

    // إشعار للمستأجر
    await sendNotification({
      recipients: [contract.tenantId],
      message: `💰 تم تحديث حالة التأمين: ${deposit.status}`,
      title: "Deposit Updated",
      type: "deposit",
      actorId: req.user._id,
      entityType: "deposit",
      entityId: deposit._id,
    });

    res.status(200).json({
      message: "✅ Deposit updated successfully",
      deposit,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating deposit",
      error: error.message,
    });
  }
};

// 4. جلب جميع التأمينات (للأدمن، المالك، أو المستأجر)
export const getAllDeposits = async (req, res) => {
  try {
    const filter = {};

    // إذا لم يكن أدمن، عرض فقط تأمينات عقوده
    if (req.user.role !== "admin") {
      if (req.user.role === "landlord") {
        // المالك: عرض ودائع عقوده فقط
        const userContracts = await Contract.find({
          landlordId: req.user._id,
        });
        const contractIds = userContracts.map((c) => c._id);
        filter.contractId = { $in: contractIds };
      } else if (req.user.role === "tenant") {
        // المستأجر: عرض ودائع عقوده فقط
        const userContracts = await Contract.find({
          tenantId: req.user._id,
        });
        const contractIds = userContracts.map((c) => c._id);
        filter.contractId = { $in: contractIds };
      }
    }

    const deposits = await Deposit.find(filter)
      .populate({
        path: "contractId",
        populate: [
          { path: "tenantId", select: "name email" },
          { path: "landlordId", select: "name email" },
        ],
      })
      .sort({ createdAt: -1 });

    res.status(200).json(deposits);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching deposits",
      error: error.message,
    });
  }
};

// 5. حذف تأمين
export const deleteDeposit = async (req, res) => {
  try {
    const deposit = await Deposit.findById(req.params.id);
    if (!deposit) {
      return res.status(404).json({ message: "Deposit not found" });
    }

    const contract = await Contract.findById(deposit.contractId);
    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    // التحقق من الصلاحيات (مالك، أدمن، أو مستأجر للعقد)
    const isLandlord = String(contract.landlordId) === String(req.user._id);
    const isTenant = String(contract.tenantId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";

    // المالك، الأدمن، أو المستأجر يمكنهم حذف الوديعة
    if (!isLandlord && !isAdmin && !isTenant) {
      return res.status(403).json({
        message: "You are not authorized to delete this deposit",
      });
    }

    // التحقق من أن الوديعة لم يتم خصم منها أو استردادها
    // إذا كان هناك خصومات أو استردادات، لا يمكن حذف الوديعة
    if ((deposit.totalDeducted || 0) > 0 || (deposit.refundedAmount || 0) > 0) {
      return res.status(400).json({
        message: "Cannot delete deposit with deductions or refunds. Please refund the remaining amount first.",
      });
    }

    await Deposit.findByIdAndDelete(req.params.id);

    // إشعار للمستأجر
    await sendNotification({
      recipients: [contract.tenantId],
      message: `💰 تم حذف الوديعة المرتبطة بعقدك`,
      title: "Deposit Deleted",
      type: "deposit",
      actorId: req.user._id,
      entityType: "deposit",
      entityId: deposit._id,
    });

    res.status(200).json({
      message: "🗑️ Deposit deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting deposit",
      error: error.message,
    });
  }
};
