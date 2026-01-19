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

    // إنشاء invoiceNumber قبل إنشاء الـ invoice
    const invoiceCount = await Invoice.countDocuments();
    const invoiceNumber = `INV-${Date.now()}-${invoiceCount + 1}`;
    
    // إنشاء فاتورة
    const invoice = new Invoice({
      paymentId,
      contractId: payment.contractId._id,
      invoiceNumber: invoiceNumber, // ✅ إضافة invoiceNumber يدوياً
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

    // إذا لم يكن أدمن، عرض فقط فواتير عقوده
    let userContracts = [];
    if (req.user.role !== "admin") {
      userContracts = await Contract.find({
        $or: [
          { landlordId: req.user._id },
          { tenantId: req.user._id },
        ],
      });
      const contractIds = userContracts.map((c) => c._id.toString());
      
      // إذا كان هناك contractId في query، نتحقق من أنه ضمن عقود المستخدم
      if (contractId) {
        if (contractIds.includes(contractId.toString())) {
          filter.contractId = contractId;
        } else {
          // المستخدم ليس لديه صلاحية على هذا العقد
          return res.status(200).json([]);
        }
      } else {
        filter.contractId = { $in: contractIds };
      }
    } else {
      userContracts = await Contract.find({});
      if (contractId) {
        filter.contractId = contractId;
      }
    }

    // ✅ إنشاء invoices تلقائياً للدفعات المفقودة في العقود الفعالة
    let createdCount = 0;
    try {
      const activeContracts = userContracts.filter(
        (c) => (c.status === "active" || c.status === "rented") && c.rentAmount && c.rentAmount > 0
      );
      
      console.log(`📋 Checking ${activeContracts.length} active contracts for missing invoices...`);
      
      for (const contract of activeContracts) {
        // جلب جميع الدفعات للعقد
        const payments = await Payment.find({ contractId: contract._id });
        
        for (const payment of payments) {
          // التحقق من وجود invoice للدفعة
          const existingInvoice = await Invoice.findOne({ paymentId: payment._id });
          
          if (!existingInvoice && payment.status === "paid") {
            // إنشاء invoice تلقائياً للدفعة المدفوعة
            try {
              // إنشاء invoiceNumber قبل إنشاء الـ invoice
              const invoiceCount = await Invoice.countDocuments();
              const invoiceNumber = `INV-${Date.now()}-${invoiceCount + 1}`;
              
              const invoice = new Invoice({
                paymentId: payment._id,
                contractId: contract._id,
                invoiceNumber: invoiceNumber, // ✅ إضافة invoiceNumber يدوياً
                items: [
                  {
                    description: payment.amount === contract.rentAmount 
                      ? "Initial Rent Payment" 
                      : "Rent Payment",
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
              createdCount++;
              console.log(`✅ Auto-created invoice ${invoice.invoiceNumber} for payment ${payment._id} (contract: ${contract._id})`);
            } catch (invoiceError) {
              console.error(`⚠️ Error creating invoice for payment ${payment._id}:`, invoiceError.message);
            }
          }
        }
      }
      
      if (createdCount > 0) {
        console.log(`✅ Created ${createdCount} invoices automatically`);
      }
    } catch (autoCreateError) {
      console.error(`⚠️ Error in auto-creating invoices:`, autoCreateError);
      // لا نفشل العملية إذا فشل إنشاء invoices تلقائياً
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
          { path: "propertyId", select: "title address" },
        ],
      })
      .sort({ issuedAt: -1 });

    console.log(`📄 Returning ${invoices.length} invoices for user ${req.user._id} (role: ${req.user.role})`);
    res.status(200).json(invoices);
  } catch (error) {
    console.error(`❌ Error fetching invoices:`, error);
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

