// controllers/contractController.js
import Contract from "../models/Contract.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";
import Property from "../models/Property.js";
import Unit from "../models/Unit.js";
import OccupancyHistory from "../models/OccupancyHistory.js";
import upload, { uploadToCloudinary } from "../middleware/uploadMiddleware.js";
import Payment from "../models/Payment.js";
import Invoice from "../models/Invoice.js";

export const addContract = async (req, res) => {
  try {
    const { propertyId, unitId } = req.body;

    // إذا كان هناك unitId، التحقق من الوحدة
    if (unitId) {
      const unit = await Unit.findById(unitId);
      if (!unit) {
        return res.status(404).json({ message: "Unit not found" });
      }

      // التحقق من أن الوحدة متاحة
      if (unit.status === "occupied") {
        const activeContract = await Contract.findOne({
          unitId: unit._id,
          status: "active",
        });
        if (activeContract) {
          return res.status(400).json({
            message: "Unit is already occupied by an active contract",
          });
        }
      }
    }

    // إذا كان هناك propertyId فقط (للتوافق مع الكود القديم)
    if (propertyId && !unitId) {
      const property = await Property.findById(propertyId);
      if (property) {
        const propertyStatus = (property.status || "available").toLowerCase();
        if (["rented", "sold", "active"].includes(propertyStatus)) {
          return res.status(400).json({
            message:
              "Cannot create a new contract for a property that is not available.",
          });
        }
      }

      // ✅ التحقق من وجود عقد Active أو Pending لنفس العقار
      const { tenantId } = req.body;
      if (tenantId) {
        const existingContract = await Contract.findOne({
          propertyId,
          tenantId,
          status: { $in: ["active", "rented", "pending"] },
        });

        if (existingContract) {
          return res.status(400).json({
            message: "A contract (active, rented, or pending) already exists for this property and tenant.",
          });
        }
      }
    }

    const contract = new Contract(req.body);
    await contract.save();
    
    // ✅ إنشاء دفعة تلقائية إذا كان العقد active أو rented (مطلوب لتفعيل العقد)
    const contractStatus = (contract.status || "").toLowerCase();
    if ((contractStatus === "active" || contractStatus === "rented")) {
      if (!contract.rentAmount || contract.rentAmount <= 0) {
        // إذا لم يكن هناك rentAmount، لا يمكن تفعيل العقد
        await Contract.findByIdAndUpdate(contract._id, { status: "pending" });
        return res.status(400).json({
          message: "Cannot activate contract: rentAmount is required. Every active contract must have at least one payment.",
        });
      }
      
      const existingPayments = await Payment.find({ contractId: contract._id });
      if (existingPayments.length === 0) {
        // ✅ إنشاء دفعة أولية عند إنشاء عقد نشط - تكون جاهزة (paid) عند تسليم العقد
        const initialPayment = new Payment({
          contractId: contract._id,
          amount: contract.rentAmount,
          method: "cash",
          status: "paid", // ✅ الدفعة الأولى تكون جاهزة (paid) عند تفعيل العقد
          date: contract.startDate || new Date(),
        });
        await initialPayment.save();
        console.log(`✅ Created initial payment for new active contract ${contract._id}: Amount=${contract.rentAmount}, Status=paid`);
      }
    }
    
    // إشعار للمستأجر
    await sendNotification({
      recipients: [contract.tenantId],
      message: "📄 تم إنشاء عقد إيجار جديد معك",
      title: "New Contract",
      type: "contract",
      actorId: req.user?._id,
      entityType: "contract",
      entityId: contract._id,
      link: `/contracts/${contract._id}`,
    });

    // إشعار للمالك
    await sendNotification({
      recipients: [contract.landlordId],
      message: "🏠 تم تسجيل عقد جديد لعقارك",
      title: "Contract Created",
      type: "contract",
      actorId: req.user?._id,
      entityType: "contract",
      entityId: contract._id,
      link: `/contracts/${contract._id}`,
    });

    res
      .status(201)
      .json({ message: "✅ Contract created successfully", contract });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error creating contract", error: error.message });
  }
};

// 2. طلب استئجار (خاص بالمستأجر - ينشئ عقد معلق + إشعار للموافقة)
export const requestContract = async (req, res) => {
  try {
    // ✅ التحقق من أن المستخدم tenant
    if (req.user.role !== "tenant") {
      return res.status(403).json({
        message: "🚫 Only tenants can request rental contracts",
      });
    }

    // ✅ دعم كل من rentAmount أو price (عشان لو الفرونت يبعت price)
    const { propertyId, rentAmount, price } = req.body;
    const tenantId = req.user._id;

    // ✅ 1) نحضر العقار أولاً
    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // ✅ قاعدة: من ينشئ الشيء هو الذي يجب أن يستقبل الطلب
    // landlordId يأتي من property.ownerId (صاحب العقار/المنشئ)
    const landlordId = property.ownerId;

    // ✅ 2) نمنع الطلب إذا حالة العقار مش متاحة
    const propertyStatus = (property.status || "available").toLowerCase();

    if (["rented", "sold", "active"].includes(propertyStatus)) {
      return res.status(400).json({
        message: `This property is already ${propertyStatus.toUpperCase()} and cannot accept new requests.`,
      });
    }

    // ✅ التحقق من وجود عقد Active لنفس العقار
    const existingActive = await Contract.findOne({
      propertyId,
      status: { $in: ["active", "rented"] },
    });

    if (existingActive) {
      return res.status(400).json({
        message: "There is already an active contract for this property.",
      });
    }

    // ✅ التحقق من وجود عقد Pending لنفس العقار والمستأجر (منع التكرار)
    const existingPending = await Contract.findOne({
      propertyId,
      tenantId,
      status: "pending",
    });

    if (existingPending) {
      return res.status(400).json({
        message: "You already have a pending contract request for this property. Please wait for approval.",
      });
    }

    // ✅ التحقق من حالة العقار (pending_approval)
    if (propertyStatus === "pending_approval") {
      const existingPendingForProperty = await Contract.findOne({
        propertyId,
        status: "pending",
      });

      if (existingPendingForProperty) {
        return res.status(400).json({
          message: "There is already a pending contract request for this property. Please wait for approval.",
        });
      }
    }

    // ✅ 3) تأكيد وجود مبلغ الإيجار
    const finalRentAmount = rentAmount ?? price;
    if (!finalRentAmount) {
      return res.status(400).json({
        message: "rentAmount (or price) is required to create a contract.",
      });
    }

    // ✅ 4) إنشاء عقد مبدئي بحالة 'pending'
    const newContract = new Contract({
      propertyId,
      tenantId,
      landlordId,
      rentAmount: finalRentAmount,
      startDate: new Date(),
      endDate: new Date(new Date().setFullYear(new Date().getFullYear() + 1)),
      status: "pending",
    });

    await newContract.save();

    // (اختياري لكن جميل) تحديث حالة العقار إلى pending_approval
    property.status = "pending_approval";
    await property.save();

    // 5) إرسال إشعار للمستأجر (تأكيد الطلب)
    await sendNotification({
      recipients: [tenantId],
      title: "✅ تم إرسال طلب الاستئجار",
      message: `تم إرسال طلب الاستئجار بنجاح. في انتظار الموافقة`,
      type: "contract_request",
      actorId: tenantId,
      entityType: "contract",
      entityId: newContract._id,
      link: `/contracts/${newContract._id}`,
    });

    // 6) إرسال إشعار للمالك
    await sendNotification({
      recipients: [landlordId],
      title: "🏠 طلب استئجار جديد",
      message: `طلب مستأجر جديد لاستئجار عقارك. اضغط للموافقة`,
      type: "contract_request",
      actorId: tenantId,
      entityType: "contract",
      entityId: newContract._id,
      link: `/contracts/${newContract._id}`,
    });

    // 7) إشعار للأدمن
    await notifyAdmins({
      title: "📋 طلب عقد جديد",
      message: `تم إنشاء طلب عقد جديد يحتاج للمراجعة`,
      type: "contract_request",
      actorId: tenantId,
      entityType: "contract",
      entityId: newContract._id,
    });

    res.status(201).json({
      message:
        "Request sent successfully. Contract created (pending approval).",
      contract: newContract,
    });
  } catch (error) {
    console.error("Error requesting contract:", error);
    res
      .status(500)
      .json({ message: "Error requesting contract", error: error.message });
  }
};


// 3. جلب جميع العقود (للأدمن)
export const getAllContracts = async (req, res) => {
  try {
    const contracts = await Contract.find()
      .populate("propertyId", "title price")
      .populate("unitId", "unitNumber floor rentPrice")
      .populate("tenantId", "name email")
      .populate("landlordId", "name email");

    // ✅ التحقق من العقود النشطة وإصلاحها (إضافة دفعة إذا لم تكن موجودة)
    for (const contract of contracts) {
      if ((contract.status === "active" || contract.status === "rented") && contract.rentAmount) {
        const existingPayments = await Payment.find({ contractId: contract._id });
        if (existingPayments.length === 0) {
          // إنشاء دفعة أولية تلقائياً
          const initialPayment = new Payment({
            contractId: contract._id,
            amount: contract.rentAmount,
            method: "cash",
            status: "pending",
            date: contract.startDate || new Date(),
          });
          await initialPayment.save();
        }
      }
    }

    res.status(200).json(contracts);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching contracts", error: error.message });
  }
};

// 4. جلب عقد محدد
export const getContractById = async (req, res) => {
  try {
    const contract = await Contract.findById(req.params.id)
      .populate("propertyId", "title price address type operation city country") // ✅ إضافة type, operation, city, country
      .populate("unitId", "unitNumber floor rentPrice status")
      .populate("tenantId", "name email phone")
      .populate("landlordId", "name email phone");

    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    // ✅ إذا كان العقد نشطاً ولا يحتوي على دفعات، إنشاء دفعة أولية تلقائياً
    const contractStatus = (contract.status || "").toLowerCase();
    if ((contractStatus === "active" || contractStatus === "rented") && contract.rentAmount && contract.rentAmount > 0) {
      const existingPayments = await Payment.find({ contractId: contract._id });
      
      if (existingPayments.length === 0) {
        // ✅ إنشاء دفعة أولية تلقائياً للعقود النشطة الموجودة التي لا تحتوي على دفعات
        const initialPayment = new Payment({
          contractId: contract._id,
          amount: contract.rentAmount,
          method: "cash",
          status: "paid", // ✅ الدفعة الأولى تكون جاهزة (paid) عند تفعيل العقد
          date: contract.startDate || new Date(),
        });
        await initialPayment.save();
        console.log(`✅ Auto-created initial payment for active contract ${contract._id}: Amount=${contract.rentAmount}, Status=paid`);
      }
    }

    res.status(200).json(contract);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching contract", error: error.message });
  }
};

// 5. جلب عقود مستخدم معين
export const getContractsByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const contracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .populate("propertyId", "title price")
      .populate("unitId", "unitNumber floor rentPrice")
      .populate("tenantId", "name")
      .populate("landlordId", "name");

    // ✅ التحقق من العقود النشطة وإصلاحها (إذا كانت بدون دفعات، تغيير حالتها)
    for (const contract of contracts) {
      if ((contract.status === "active" || contract.status === "rented") && contract.rentAmount) {
        const existingPayments = await Payment.find({ contractId: contract._id });
        if (existingPayments.length === 0) {
          // إذا كان العقد نشط بدون دفعات، إنشاء دفعة أولية
          const Payment = (await import('../models/Payment.js')).default;
          const initialPayment = new Payment({
            contractId: contract._id,
            amount: contract.rentAmount,
            method: "cash",
            status: "pending",
            date: contract.startDate || new Date(),
          });
          await initialPayment.save();
        }
      }
    }

    if (!contracts.length)
      return res
        .status(404)
        .json({ message: "No contracts found for this user" });

    res.status(200).json(contracts);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching user contracts",
      error: error.message,
    });
  }
};

// 6. تحديث العقد (تستخدم للموافقة وتغيير الحالة إلى active)
export const updateContract = async (req, res) => {
  try {
    // ✅ الحصول على العقد القديم أولاً للتحقق من الحالة السابقة
    const oldContract = await Contract.findById(req.params.id);
    if (!oldContract) {
      return res.status(404).json({ message: "❌ Contract not found" });
    }
    
    const contract = await Contract.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );

    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    // ✅ لو بدنا نفعّل العقد
    if (req.body.status === "rented" || req.body.status === "active") {
      // إذا كان العقد مرتبط بوحدة
      if (contract.unitId) {
        const unit = await Unit.findById(contract.unitId);
        if (unit) {
          // التحقق من عدم وجود عقد نشط آخر للوحدة
          const anotherActive = await Contract.findOne({
            _id: { $ne: contract._id },
            unitId: contract.unitId,
            status: { $in: ["rented", "active"] },
          });

          if (anotherActive) {
            await Contract.findByIdAndUpdate(contract._id, { status: "pending" });
            return res.status(400).json({
              message: "Another active contract already exists for this unit.",
            });
          }

          // تحديث حالة الوحدة
          unit.status = "occupied";
          await unit.save();

          // إنشاء سجل إشغال
          await OccupancyHistory.create({
            unitId: contract.unitId,
            tenantId: contract.tenantId,
            contractId: contract._id,
            from: contract.startDate || new Date(),
            to: contract.endDate || null,
          });
        }
      } else if (contract.propertyId) {
        // للتوافق مع الكود القديم (عقود مرتبطة بعقار مباشرة)
        const anotherActive = await Contract.findOne({
          _id: { $ne: contract._id },
          propertyId: contract.propertyId,
          status: { $in: ["rented", "active"] },
        });

        if (anotherActive) {
          await Contract.findByIdAndUpdate(contract._id, { status: "pending" });
          return res.status(400).json({
            message: "Another rented contract already exists for this property.",
          });
        }

        await Property.findByIdAndUpdate(contract.propertyId, {
          status: "rented",
        });
      }
    }

    // ✅ التحقق من وجود دفعة واحدة على الأقل للعقود النشطة (مطلوب دائماً)
    // هذا يعني: لا يمكن تفعيل عقد بدون وجود دفعة على الأقل
    const isActiveOrRented = contract.status === "active" || contract.status === "rented";
    const wasActiveOrRented = oldContract.status === "active" || oldContract.status === "rented";
    
    // إذا كان العقد يتم تفعيله الآن (من حالة أخرى إلى active/rented)
    const isBeingActivated = !wasActiveOrRented && isActiveOrRented;
    
    console.log(`🔍 Contract Update Debug:`, {
      contractId: contract._id,
      oldStatus: oldContract.status,
      newStatus: contract.status,
      isActiveOrRented,
      wasActiveOrRented,
      isBeingActivated,
      rentAmount: contract.rentAmount
    });
    
    if (isActiveOrRented) {
      const existingPayments = await Payment.find({ contractId: contract._id });
      console.log(`🔍 Existing payments count: ${existingPayments.length} for contract ${contract._id}`);
      
      // ✅ إذا لم تكن هناك دفعات موجودة على الإطلاق - يجب إنشاء دفعة أولية
      if (existingPayments.length === 0) {
        // إذا كان العقد يتم تفعيله الآن (من pending إلى active/rented)
        if (isBeingActivated) {
          // التحقق من وجود rentAmount - مطلوب لإنشاء دفعة أولية
          if (!contract.rentAmount || contract.rentAmount <= 0) {
            // إرجاع العقد إلى الحالة السابقة إذا لم يكن هناك rentAmount
            await Contract.findByIdAndUpdate(contract._id, { status: oldContract.status });
            console.log(`❌ Cannot activate: rentAmount is missing or invalid (${contract.rentAmount})`);
            return res.status(400).json({
              message: "Cannot activate contract: rentAmount is required. Every active contract must have at least one payment. Please add a payment before activating the contract.",
            });
          }
          
          try {
            // ✅ إنشاء دفعة أولية تلقائياً عند الموافقة على العقد (من pending إلى active/rented)
            // هذه هي الدفعة الأولية المطلوبة لكل عقد نشط - تكون جاهزة (paid) عند تسليم العقد
            const initialPayment = new Payment({
              contractId: contract._id,
              amount: contract.rentAmount,
              method: "cash",
              status: "paid", // ✅ الدفعة الأولى تكون جاهزة (paid) عند تفعيل العقد
              date: contract.startDate || new Date(),
            });
            
            const savedPayment = await initialPayment.save();
            console.log(`✅ Created initial payment for contract ${contract._id}:`, {
              paymentId: savedPayment._id,
              amount: savedPayment.amount,
              status: savedPayment.status,
              date: savedPayment.date
            });
            
            // ✅ إنشاء Invoice تلقائياً للدفعة الأولية
            try {
              const existingInvoice = await Invoice.findOne({ paymentId: savedPayment._id });
              if (!existingInvoice) {
                const invoice = new Invoice({
                  paymentId: savedPayment._id,
                  contractId: contract._id,
                  items: [
                    {
                      description: "Initial Rent Payment",
                      quantity: 1,
                      unitPrice: savedPayment.amount,
                      total: savedPayment.amount,
                    },
                  ],
                  subtotal: savedPayment.amount,
                  tax: 0,
                  total: savedPayment.amount,
                  dueDate: savedPayment.date || new Date(),
                });
                await invoice.save();
                console.log(`✅ Created invoice for initial payment: ${invoice.invoiceNumber}`);
              }
            } catch (invoiceError) {
              console.error(`⚠️ Error creating invoice for initial payment:`, invoiceError);
              // لا نفشل العملية إذا فشل إنشاء الفاتورة
            }
          } catch (paymentError) {
            console.error(`❌ Error creating initial payment:`, paymentError);
            // إرجاع العقد إلى الحالة السابقة في حالة فشل إنشاء الدفعة
            await Contract.findByIdAndUpdate(contract._id, { status: oldContract.status });
            return res.status(500).json({
              message: "Error creating initial payment. Contract status has been reverted.",
              error: paymentError.message,
            });
          }
        } else {
          // إذا كان العقد نشط بالفعل لكن لا توجد دفعات، هذا خطأ منطقي
          // يجب إرجاع العقد إلى حالة pending لأن العقد النشط يجب أن يكون له دفعات
          await Contract.findByIdAndUpdate(contract._id, { status: "pending" });
          console.log(`❌ Invalid state: Contract is active but has no payments`);
          return res.status(400).json({
            message: "Invalid contract state: Active contracts must have at least one payment. Contract status has been changed to 'pending'. Please add payments before activating.",
          });
        }
      }
    }

    // إشعار للمستأجر عند الموافقة
    const isNowActiveOrRented = contract.status === "active" || contract.status === "rented";
    if (isNowActiveOrRented) {
      await sendNotification({
        recipients: [contract.tenantId],
        title: "✅ تم الموافقة على العقد",
        message: `تم الموافقة على عقد الإيجار الخاص بك! الحالة: ${contract.status}`,
        type: "contract",
        actorId: req.user?._id,
        entityType: "contract",
        entityId: contract._id,
        link: `/contracts/${contract._id}`,
      });

      // إشعار للمالك
      await sendNotification({
        recipients: [contract.landlordId],
        title: "✅ تم تفعيل العقد",
        message: `تم تفعيل عقد الإيجار بنجاح`,
        type: "contract",
        actorId: req.user?._id,
        entityType: "contract",
        entityId: contract._id,
        link: `/contracts/${contract._id}`,
      });
    }
    
    // ✅ جلب الدفعات المحدثة لإرجاعها في الـ response
    const updatedPayments = await Payment.find({ contractId: contract._id }).sort({ date: -1 });
    
    // ✅ التحقق من أن الدفعة الأولية تم إنشاؤها (إذا كان العقد تم تفعيله وكانت هناك دفعات جديدة)
    const initialPaymentCreated = isBeingActivated && updatedPayments.length > 0 && 
                                   updatedPayments.some(p => p.status === 'paid' && p.method === 'cash');
    
    res
      .status(200)
      .json({ 
        message: initialPaymentCreated 
          ? "✅ Contract updated successfully. Initial payment created automatically." 
          : "✅ Contract updated successfully", 
        contract,
        payments: updatedPayments, // ✅ إرجاع الدفعات المحدثة
        initialPaymentCreated // ✅ إعلام بأن الدفعة الأولية تم إنشاؤها
      });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating contract",
      error: error.message,
    });
  }
};


// 7. حذف عقد
export const deleteContract = async (req, res) => {
  try {
    const contract = await Contract.findByIdAndDelete(req.params.id);

    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    res.status(200).json({ message: "🗑️ Contract deleted successfully" });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error deleting contract", error: error.message });
  }
};

// ✍️ توقيع إلكتروني للعقد
export const signContract = async (req, res) => {
  try {
    const userId = String(req.user._id);
    const contract = await Contract.findById(req.params.id);

    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    // التحقق أن المستخدم طرف في العقد
    const isTenant = String(contract.tenantId) === userId;
    const isLandlord = String(contract.landlordId) === userId;

    if (!isTenant && !isLandlord) {
      return res
        .status(403)
        .json({ message: "You are not allowed to sign this contract" });
    }

    // تحديد من هو الموقّع
    const signerKey = isLandlord ? "landlord" : "tenant";

    // لو سبق ووقّع
    if (contract.signatures?.[signerKey]?.signed) {
      return res
        .status(400)
        .json({ message: "You have already signed this contract" });
    }

    // حفظ التوقيع
    contract.signatures = contract.signatures || {};
    contract.signatures[signerKey] = {
      signed: true,
      signedAt: new Date(),
    };

    // لو الطرفين وقّعوا → العقد يصبح Active
    if (
      contract.signatures.landlord?.signed &&
      contract.signatures.tenant?.signed
    ) {
      contract.status = "active";
    }

    await contract.save();

    // إرسال إشعار للطرف الآخر
    const otherPartyId = isLandlord ? contract.tenantId : contract.landlordId;
    await sendNotification({
      recipients: [otherPartyId],
      title: "Contract Signed",
      message: "The other party has signed the contract.",
      type: "contract",
      actorId: req.user._id,
      entityType: "contract",
      entityId: contract._id,
    });

    res.status(200).json({
      message: "Contract signed successfully",
      contract,
    });
  } catch (error) {
    console.error("Error signing contract:", error);
    res.status(500).json({
      message: "Error signing contract",
      error: error.message,
    });
  }
};

// 📄 رفع/تحديث ملف PDF للعقد
export const uploadContractPdf = async (req, res) => {
  try {
    const contractId = req.params.id;

    if (!req.file) {
      return res.status(400).json({ message: "No file uploaded" });
    }

    const result = await uploadToCloudinary(req.file.buffer);

    const contract = await Contract.findByIdAndUpdate(
      contractId,
      { pdfUrl: result.secure_url },
      { new: true }
    );

    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    res.status(200).json({
      message: "Contract PDF uploaded successfully",
      pdfUrl: contract.pdfUrl,
      contract,
    });
  } catch (error) {
    console.error("Error uploading contract PDF:", error);
    res.status(500).json({
      message: "Error uploading contract PDF",
      error: error.message,
    });
  }
};

// 🔁 تجديد عقد
export const renewContract = async (req, res) => {
  try {
    const { newStartDate, newEndDate } = req.body;
    const contract = await Contract.findById(req.params.id);

    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    const userId = String(req.user._id);
    if (
      String(contract.landlordId) !== userId &&
      String(contract.tenantId) !== userId &&
      req.user.role !== "admin"
    ) {
      return res
        .status(403)
        .json({ message: "You are not allowed to renew this contract" });
    }

    const currentEnd = contract.endDate || new Date();

    contract.startDate = newStartDate ? new Date(newStartDate) : currentEnd;
    contract.endDate = newEndDate
      ? new Date(newEndDate)
      : new Date(
          new Date(contract.startDate).setFullYear(
            new Date(contract.startDate).getFullYear() + 1
          )
        );

    contract.status = "active";
    contract.renewalCount = (contract.renewalCount || 0) + 1;
    contract.lastRenewedAt = new Date();

    await contract.save();

    // ✅ إنشاء دفعة تلقائية عند التجديد (إذا لم تكن موجودة)
    const existingPayments = await Payment.find({ contractId: contract._id });
    if (existingPayments.length === 0 && contract.rentAmount) {
      const initialPayment = new Payment({
        contractId: contract._id,
        amount: contract.rentAmount,
        method: "cash",
        status: "pending",
        date: contract.startDate || new Date(),
      });
      await initialPayment.save();
    }

    const otherPartyId =
      String(contract.landlordId) === userId
        ? contract.tenantId
        : contract.landlordId;

    await sendNotification({
      recipients: [otherPartyId],
      title: "Contract Renewed",
      message: "The rental contract has been renewed.",
      type: "contract",
      actorId: req.user._id,
      entityType: "contract",
      entityId: contract._id,
    });

    res.status(200).json({
      message: "Contract renewed successfully",
      contract,
    });
  } catch (error) {
    console.error("Error renewing contract:", error);
    res.status(500).json({
      message: "Error renewing contract",
      error: error.message,
    });
  }
};

// 🧨 طلب إنهاء عقد
export const requestTermination = async (req, res) => {
  try {
    const { reason } = req.body;
    const userId = String(req.user._id);

    const contract = await Contract.findById(req.params.id);

    if (!contract) {
      return res.status(404).json({ message: "Contract not found" });
    }

    const isTenant = String(contract.tenantId) === userId;
    const isLandlord = String(contract.landlordId) === userId;

    if (!isTenant && !isLandlord && req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "You are not allowed to terminate this contract" });
    }

    contract.termination = {
      requestedBy: req.user._id,
      reason,
      requestedAt: new Date(),
    };

    contract.status = "terminated";

    await contract.save();

    const otherPartyId = isLandlord ? contract.tenantId : contract.landlordId;

    await sendNotification({
      recipients: [otherPartyId],
      title: "Contract Termination",
      message: "The other party requested contract termination.",
      type: "contract",
      actorId: req.user._id,
      entityType: "contract",
      entityId: contract._id,
    });

    res.status(200).json({
      message: "Termination requested successfully",
      contract,
    });
  } catch (error) {
    console.error("Error requesting termination:", error);
    res.status(500).json({
      message: "Error requesting termination",
      error: error.message,
    });
  }
};

// ✅ جلب إحصائيات العقد (الدفعات، الفواتير، الإجمالي)
export const getContractStatistics = async (req, res) => {
  try {
    const { id } = req.params;
    const contract = await Contract.findById(id);

    if (!contract) {
      return res.status(404).json({ message: "❌ Contract not found" });
    }

    // التحقق من الصلاحيات
    const isParty =
      String(contract.tenantId) === String(req.user._id) ||
      String(contract.landlordId) === String(req.user._id);

    if (!isParty && req.user.role !== "admin") {
      return res.status(403).json({
        message: "🚫 You can only view your own contract statistics",
      });
    }

    // جلب جميع الدفعات
    const payments = await Payment.find({ contractId: id }).sort({ date: -1 });
    
    // جلب جميع الفواتير
    const invoices = await Invoice.find({ contractId: id }).sort({ issuedAt: -1 });

    // حساب الإحصائيات
    const totalPayments = payments.length;
    const paidPayments = payments.filter((p) => p.status === "paid").length;
    const pendingPayments = payments.filter((p) => p.status === "pending").length;
    const failedPayments = payments.filter((p) => p.status === "failed").length;

    const totalPaid = payments
      .filter((p) => p.status === "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);
    
    const totalPending = payments
      .filter((p) => p.status === "pending")
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const contractAmount = contract.rentAmount || 0;
    const contractDuration = contract.endDate && contract.startDate
      ? Math.ceil((new Date(contract.endDate) - new Date(contract.startDate)) / (1000 * 60 * 60 * 24 * 30))
      : 0;

    // حساب المتبقي (تقديري)
    const estimatedTotal = contractAmount * contractDuration;
    const remainingAmount = estimatedTotal - totalPaid;

    // آخر دفعة مدفوعة
    const lastPaidPayment = payments.find((p) => p.status === "paid");
    const lastPaymentDate = lastPaidPayment?.date || null;

    res.status(200).json({
      payments: {
        total: totalPayments,
        paid: paidPayments,
        pending: pendingPayments,
        failed: failedPayments,
        totalPaid,
        totalPending,
        lastPaymentDate,
      },
      invoices: {
        total: invoices.length,
        list: invoices,
      },
      financial: {
        contractAmount,
        totalPaid,
        totalPending,
        remainingAmount: remainingAmount > 0 ? remainingAmount : 0,
        contractDuration,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching contract statistics",
      error: error.message,
    });
  }
};