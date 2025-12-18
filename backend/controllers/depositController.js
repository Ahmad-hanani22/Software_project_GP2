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

    // التحقق من الصلاحيات (مالك أو أدمن)
    if (
      String(contract.landlordId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to add deposit for this contract",
      });
    }

    // التحقق من عدم وجود تأمين موجود
    const existingDeposit = await Deposit.findOne({ contractId });
    if (existingDeposit) {
      return res.status(400).json({
        message: "Deposit already exists for this contract",
      });
    }

    const deposit = new Deposit({
      contractId,
      amount,
      currency: req.body.currency || "USD",
      status: "held",
    });
    await deposit.save();

    // إشعار للمستأجر
    await sendNotification({
      recipients: [contract.tenantId],
      message: `💰 تأمين بقيمة ${amount} تم استلامه`,
      title: "Deposit Received",
      type: "deposit",
      actorId: req.user._id,
      entityType: "deposit",
      entityId: deposit._id,
    });

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

    // التحقق من الصلاحيات
    if (
      String(contract.landlordId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
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

// 4. جلب جميع التأمينات (للأدمن أو المالك)
export const getAllDeposits = async (req, res) => {
  try {
    const filter = {};

    // إذا لم يكن أدمن، عرض فقط تأمينات عقوده
    if (req.user.role !== "admin") {
      const userContracts = await Contract.find({
        landlordId: req.user._id,
      });
      const contractIds = userContracts.map((c) => c._id);
      filter.contractId = { $in: contractIds };
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

