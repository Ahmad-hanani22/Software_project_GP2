import Payment from "../models/Payment.js";
import Contract from "../models/Contract.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";


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

    const payment = new Payment({
      contractId,
      amount,
      method,
      status: "pending",
      date: new Date(),
      receiptUrl,
    });
    await payment.save();

 
    await sendNotification({
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

    await sendNotification({
      userId: contract.landlordId._id,
      message: `📥 استلمت دفعة جديدة من ${contract.tenantId.name} بقيمة ${amount}`,
      type: "payment",
      actorId: req.user._id,
      entityType: "payment",
      entityId: payment._id,
      link: `/payments/${payment._id}`,
    });

    await notifyAdmins({
      message: `🧾 دفعة جديدة قيد المراجعة من المستأجر ${contract.tenantId.name}`,
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
 📋 عرض كل الدفعات (Admin فقط)
========================================================= */
export const getAllPayments = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "🚫 Only admin can view all payments" });
    }

    const payments = await Payment.find()
      .populate("contractId", "rentAmount startDate endDate")
      .sort({ date: -1 });

    res.status(200).json(payments);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching payments", error: error.message });
  }
};

/* =========================================================
 📄 عرض دفعات عقد معيّن (المالك / المستأجر / الأدمن)
========================================================= */
export const getPaymentsByContract = async (req, res) => {
  try {
    const { contractId } = req.params;
    const contract = await Contract.findById(contractId).populate(
      "tenantId landlordId"
    );
    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    // 🔐 صلاحية المشاهدة
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
 👤 عرض دفعات مستخدم معيّن (Tenant/Landlord/Admin)
========================================================= */
export const getPaymentsByUser = async (req, res) => {
  try {
    const { userId } = req.params;

    // 🔐 السماح فقط للمستخدم نفسه أو الأدمن
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
 ✏️ تحديث حالة دفعة (Landlord/Admin)
========================================================= */
export const updatePayment = async (req, res) => {
  try {
    if (!["landlord", "admin"].includes(req.user.role)) {
      return res
        .status(403)
        .json({ message: "🚫 Only landlord or admin can update payments" });
    }

    const payment = await Payment.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });
    if (!payment)
      return res.status(404).json({ message: "❌ Payment not found" });

    const contract = await Contract.findById(payment.contractId).populate(
      "tenantId landlordId",
      "name"
    );

    // 🔔 إشعار للمستأجر بتحديث الحالة
    await sendNotification({
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
