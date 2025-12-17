// controllers/paymentController.js

import Payment from "../models/Payment.js";
import Contract from "../models/Contract.js";
import { sendNotificationToUser, notifyAdmins } from "../utils/sendNotification.js";

export const addPayment = async (req, res) => {
  try {
    const { contractId, amount, method, receiptUrl } = req.body;

    if (req.user.role !== "tenant") {
      return res
        .status(403)
        .json({ message: "🚫 Only tenants can make payments" });
    }

    const contract = await Contract.findById(contractId).populate(
      "tenantId landlordId",
      "name email"
    );
    if (!contract) {
      return res.status(404).json({ message: "❌ Contract not found" });
    }

    // Validate contract has required fields
    if (!contract.tenantId) {
      return res.status(400).json({ message: "❌ Contract is missing tenant information" });
    }

    const payment = new Payment({
      contractId,
      amount,
      method,
      status: "pending",
      date: new Date(),
      receiptUrl,
    });
    await payment.save();

    // Get tenant name safely
    const tenantName = contract.tenantId?.name || "Tenant";

    await sendNotificationToUser({
      userId: req.user._id,
      message: `💰 تم إرسال دفعة بقيمة ${amount} ${
        method ? `عبر ${method}` : ""
      }`,
      type: "payment",
      actorId: req.user._id,
      entityType: "payment",
      entityId: payment._id,
      link: `/payments/${payment._id}`,
    });

    // Send notification to landlord if exists
    if (contract.landlordId && contract.landlordId._id) {
      await sendNotificationToUser({
        userId: contract.landlordId._id,
        message: `📥 استلمت دفعة جديدة من ${contract.tenantId.name} بقيمة ${amount}`,
        type: "payment",
        actorId: req.user._id,
        entityType: "payment",
        entityId: payment._id,
        link: `/payments/${payment._id}`,
      });
    }

    await notifyAdmins({
      message: `🧾 دفعة جديدة قيد المراجعة من المستأجر ${tenantName}`,
      type: "payment",
      actorId: req.user._id,
      entityType: "payment",
      entityId: payment._id,
      link: `/admin/payments/${payment._id}`,
    });

    res.status(201).json({
      message: "✅ Payment added successfully",
      payment,
    });
  } catch (error) {
    console.error("❌ Error adding payment:", error);
    res
      .status(500)
      .json({ message: "❌ Error adding payment", error: error.message });
  }
};

/* =========================================================
 📋 عرض كل الدفعات (Admin فقط) - النسخة النهائية والمصححة
========================================================= */
export const getAllPayments = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "🚫 Only admin can view all payments" });
    }

    // هذا هو التصحيح الكامل: Populate المتداخل
    const payments = await Payment.find()
      .populate({
        path: "contractId", // 1. اذهب إلى العقد
        populate: [
          { path: "tenantId", select: "name email" },   // 2. من العقد، اذهب للمستأجر
          { path: "propertyId", select: "title" },  // 3. من العقد، اذهب للعقار
        ],
      })
      .sort({ date: -1 });

    res.status(200).json(payments);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching payments", error: error.message });
  }
};

/* =========================================================
 📄 عرض دفعات عقد معيّن
========================================================= */
export const getPaymentsByContract = async (req, res) => {
  try {
    const { contractId } = req.params;
    const contract = await Contract.findById(contractId).populate(
      "tenantId landlordId"
    );
    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    const isParty =
      String(contract.tenantId._id) === String(req.user._id) ||
      String(contract.landlordId._id) === String(req.user._id);

    if (!isParty && req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "🚫 You can only view your own contract payments" });
    }

    const payments = await Payment.find({ contractId }).sort({ date: -1 });
    res.status(200).json(payments);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching contract payments",
      error: error.message,
    });
  }
};

/* =========================================================
 👤 عرض دفعات مستخدم معيّن
========================================================= */
export const getPaymentsByUser = async (req, res) => {
  try {
    const { userId } = req.params;

    if (req.user.role !== "admin" && String(req.user._id) !== String(userId)) {
      return res.status(403).json({
        message: "🚫 You can only view your own payments",
      });
    }

    const contracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    }).select("_id");

    const contractIds = contracts.map((c) => c._id);
    const payments = await Payment.find({ contractId: { $in: contractIds } })
      .populate("contractId", "rentAmount startDate endDate")
      .sort({ date: -1 });

    res.status(200).json(payments);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching user payments",
      error: error.message,
    });
  }
};

/* =========================================================
 ✏️ تحديث حالة دفعة - النسخة النهائية والمصححة
========================================================= */
export const updatePayment = async (req, res) => {
  try {
    if (!["landlord", "admin"].includes(req.user.role)) {
      return res
        .status(403)
        .json({ message: "🚫 Only landlord or admin can update payments" });
    }

    const payment = await Payment.findById(req.params.id);
    if (!payment) {
        return res.status(404).json({ message: "❌ Payment not found" });
    }
    
    payment.status = req.body.status;
    await payment.save();

    const contract = await Contract.findById(payment.contractId).populate(
      "tenantId",
      "name"
    );

    if (!contract || !contract.tenantId) {
      console.warn(`⚠️ Warning: Could not find contract or tenant for payment ${payment._id} to send notification.`);
      return res
        .status(200)
        .json({ message: "✅ Payment updated, but could not send notification.", payment });
    }

    await sendNotificationToUser({
      userId: contract.tenantId._id,
      message: `🔄 تم تحديث حالة دفعتك إلى: ${payment.status}`,
      type: "payment",
      actorId: req.user._id,
      entityType: "payment",
      entityId: payment._id,
      link: `/payments/${payment._id}`,
    });

    res
      .status(200)
      .json({ message: "✅ Payment updated successfully", payment });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error updating payment", error: error.message });
  }
};

/* =========================================================
 🗑️ حذف دفعة
========================================================= */
export const deletePayment = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "🚫 Only admin can delete payments" });
    }

    const payment = await Payment.findByIdAndDelete(req.params.id);
    if (!payment)
      return res.status(404).json({ message: "❌ Payment not found" });

    res.status(200).json({ message: "🗑️ Payment deleted successfully" });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error deleting payment", error: error.message });
  }
};