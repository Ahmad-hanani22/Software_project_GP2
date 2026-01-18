// controllers/paymentController.js

import Payment from "../models/Payment.js";
import Contract from "../models/Contract.js";
import Property from "../models/Property.js";
import Invoice from "../models/Invoice.js";
import { sendNotificationToUser } from "../utils/sendNotification.js";

export const addPayment = async (req, res) => {
  try {
    const { contractId, amount, method, receiptUrl } = req.body;

    if (req.user.role !== "tenant") {
      return res
        .status(403)
        .json({ message: "🚫 Only tenants can make payments" });
    }

    const contract = await Contract.findById(contractId).populate(
      "tenantId landlordId propertyId",
      "name email ownerId"
    );
    if (!contract) {
      return res.status(404).json({ message: "❌ Contract not found" });
    }

    // Validate contract has required fields
    if (!contract.tenantId) {
      return res.status(400).json({ message: "❌ Contract is missing tenant information" });
    }

    // ✅ Get property owner (من أنشأ العقار)
    let propertyOwnerId = null;
    if (contract.propertyId) {
      // If propertyId is populated, get ownerId directly
      if (contract.propertyId.ownerId) {
        propertyOwnerId = contract.propertyId.ownerId;
      } else {
        // If not populated, fetch property separately
        const property = await Property.findById(contract.propertyId).select("ownerId");
        if (property) {
          propertyOwnerId = property.ownerId;
        }
      }
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

    // ✅ إشعار للمستأجر (من قام بالدفع)
    await sendNotificationToUser({
      userId: req.user._id,
      title: "💰 تم إرسال الدفعة",
      message: `تم إرسال دفعة بقيمة \$${amount} ${method ? `عبر ${method}` : ""}. في انتظار الموافقة`,
      type: "payment",
      actorId: req.user._id,
      entityType: "payment",
      entityId: payment._id,
      link: `/payments/${payment._id}`,
    });

    // ✅ إشعار فقط لمن أنشأ العقار (property.ownerId)
    // إذا كان ownerId هو admin → يرسل للـ admin
    // إذا كان ownerId هو landlord → يرسل للـ landlord
    if (propertyOwnerId) {
      await sendNotificationToUser({
        userId: propertyOwnerId,
        title: "📥 دفعة جديدة",
        message: `استلمت دفعة جديدة من ${tenantName} بقيمة \$${amount}. في انتظار الموافقة`,
        type: "payment",
        actorId: req.user._id,
        entityType: "payment",
        entityId: payment._id,
        link: `/payments/${payment._id}`,
      });
      console.log(`✅ Payment notification sent to property owner: ${propertyOwnerId}`);
    } else {
      console.warn(`⚠️ Warning: Property ownerId not found for contract ${contractId}`);
    }

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
 👤 عرض دفعات مستخدم معيّن (للـ Landlord أو Tenant)
========================================================= */
export const getPaymentsByUser = async (req, res) => {
  try {
    const { userId } = req.params;

    if (req.user.role !== "admin" && String(req.user._id) !== String(userId)) {
      return res.status(403).json({
        message: "🚫 You can only view your own payments",
      });
    }

    // ✅ جلب العقود التي يكون فيها المستخدم tenant أو landlord
    const contracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    }).select("_id");

    const contractIds = contracts.map((c) => c._id);
    
    // ✅ populate كامل للـ contract مع landlordId, tenantId, propertyId
    const payments = await Payment.find({ contractId: { $in: contractIds } })
      .populate({
        path: "contractId",
        populate: [
          { path: "tenantId", select: "name email" },
          { path: "landlordId", select: "name email" },
          { path: "propertyId", select: "title" },
        ],
      })
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

    const payment = await Payment.findById(req.params.id).populate("contractId");
    if (!payment) {
        return res.status(404).json({ message: "❌ Payment not found" });
    }
    
    const previousStatus = payment.status;
    
    // Update status if provided
    if (req.body.status) {
      payment.status = req.body.status;
    }
    
    // Update receiptUrl if provided
    if (req.body.receiptUrl) {
      payment.receiptUrl = req.body.receiptUrl;
    }
    
    await payment.save();

    // ✅ إنشاء Invoice تلقائياً عند قبول الدفعة (status = "paid")
    if (payment.status === "paid" && previousStatus !== "paid") {
      try {
        // التحقق من عدم وجود فاتورة موجودة لهذه الدفعة
        const existingInvoice = await Invoice.findOne({ paymentId: payment._id });
        
        if (!existingInvoice) {
          // الحصول على contractId بشكل صحيح
          const contractIdValue = payment.contractId?._id 
            ? payment.contractId._id 
            : (payment.contractId?.toString() || payment.contractId);
          
          if (!contractIdValue) {
            console.warn(`⚠️ Warning: ContractId is missing for payment ${payment._id}`);
          } else {
            // إنشاء فاتورة تلقائياً
            const invoice = new Invoice({
              paymentId: payment._id,
              contractId: contractIdValue,
              items: [
                {
                  description: "Rent Payment",
                  quantity: 1,
                  unitPrice: payment.amount,
                  total: payment.amount,
                },
              ],
              subtotal: payment.amount,
              tax: 0,
              total: payment.amount,
              dueDate: payment.date || new Date(),
            });

            await invoice.save();
            
            console.log(`✅ Invoice created automatically for payment ${payment._id}: ${invoice.invoiceNumber}`);
          }
        }
      } catch (invoiceError) {
        // في حالة فشل إنشاء الفاتورة، نسجل الخطأ ولكن لا نفشل العملية
        console.error(`⚠️ Error creating invoice for payment ${payment._id}:`, invoiceError);
      }
    }

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
      title: "🔄 تحديث حالة الدفعة",
      message: `تم تحديث حالة دفعتك إلى: ${payment.status}${payment.status === "paid" ? ". تم إنشاء الفاتورة تلقائياً" : ""}`,
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