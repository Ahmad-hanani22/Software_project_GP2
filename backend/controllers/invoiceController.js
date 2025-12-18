import Invoice from "../models/Invoice.js";
import Payment from "../models/Payment.js";
import Contract from "../models/Contract.js";

// 1. إنشاء فاتورة من دفع
export const createInvoice = async (req, res) => {
  try {
    const { paymentId } = req.body;

    const payment = await Payment.findById(paymentId).populate("contractId");
    if (!payment) {
      return res.status(404).json({ message: "Payment not found" });
    }

    // التحقق من عدم وجود فاتورة موجودة
    const existingInvoice = await Invoice.findOne({ paymentId });
    if (existingInvoice) {
      return res.status(400).json({
        message: "Invoice already exists for this payment",
      });
    }

    // إنشاء فاتورة
    const invoice = new Invoice({
      paymentId,
      contractId: payment.contractId._id,
      items: req.body.items || [
        {
          description: "Rent Payment",
          quantity: 1,
          unitPrice: payment.amount,
          total: payment.amount,
        },
      ],
      subtotal: req.body.subtotal || payment.amount,
      tax: req.body.tax || 0,
      total: req.body.total || payment.amount,
      dueDate: req.body.dueDate || payment.date,
    });

    await invoice.save();

    res.status(201).json({
      message: "✅ Invoice created successfully",
      invoice,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error creating invoice",
      error: error.message,
    });
  }
};

// 2. جلب جميع الفواتير
export const getAllInvoices = async (req, res) => {
  try {
    const { contractId } = req.query;
    const filter = {};

    if (contractId) filter.contractId = contractId;

    // إذا لم يكن أدمن، عرض فقط فواتير عقوده
    if (req.user.role !== "admin") {
      const userContracts = await Contract.find({
        $or: [
          { landlordId: req.user._id },
          { tenantId: req.user._id },
        ],
      });
      const contractIds = userContracts.map((c) => c._id);
      filter.contractId = { $in: contractIds };
    }

    const invoices = await Invoice.find(filter)
      .populate({
        path: "paymentId",
        populate: { path: "contractId" },
      })
      .populate({
        path: "contractId",
        populate: [
          { path: "tenantId", select: "name email" },
          { path: "landlordId", select: "name email" },
        ],
      })
      .sort({ issuedAt: -1 });

    res.status(200).json(invoices);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching invoices",
      error: error.message,
    });
  }
};

// 3. جلب فاتورة محددة
export const getInvoiceById = async (req, res) => {
  try {
    const invoice = await Invoice.findById(req.params.id)
      .populate({
        path: "paymentId",
        populate: { path: "contractId" },
      })
      .populate({
        path: "contractId",
        populate: [
          { path: "tenantId", select: "name email phone" },
          { path: "landlordId", select: "name email phone" },
        ],
      });

    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found" });
    }

    // التحقق من الصلاحيات
    const contract = await Contract.findById(invoice.contractId._id);
    if (
      req.user.role !== "admin" &&
      String(contract.tenantId) !== String(req.user._id) &&
      String(contract.landlordId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        message: "You are not authorized to view this invoice",
      });
    }

    res.status(200).json(invoice);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching invoice",
      error: error.message,
    });
  }
};

// 4. تحديث فاتورة (مثل رفع PDF)
export const updateInvoice = async (req, res) => {
  try {
    const invoice = await Invoice.findById(req.params.id);
    if (!invoice) {
      return res.status(404).json({ message: "Invoice not found" });
    }

    const contract = await Contract.findById(invoice.contractId);
    if (
      String(contract.landlordId) !== String(req.user._id) &&
      req.user.role !== "admin"
    ) {
      return res.status(403).json({
        message: "You are not authorized to update this invoice",
      });
    }

    const updatedInvoice = await Invoice.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );

    res.status(200).json({
      message: "✅ Invoice updated successfully",
      invoice: updatedInvoice,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating invoice",
      error: error.message,
    });
  }
};

