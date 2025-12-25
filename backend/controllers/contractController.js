// controllers/contractController.js
import Contract from "../models/Contract.js";
import { sendNotification } from "../utils/sendNotification.js";
import Property from "../models/Property.js";
import Unit from "../models/Unit.js";
import OccupancyHistory from "../models/OccupancyHistory.js";
import upload, { uploadToCloudinary } from "../Middleware/uploadMiddleware.js";

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
    }

    const contract = new Contract(req.body);
    await contract.save();
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
    // ✅ دعم كل من rentAmount أو price (عشان لو الفرونت يبعت price)
    const { propertyId, landlordId, rentAmount, price } = req.body;
    const tenantId = req.user._id;

    // ✅ 1) نحضر العقار أولاً
    const property = await Property.findById(propertyId);
    if (!property) {
      return res.status(404).json({ message: "Property not found" });
    }

    // ✅ 2) نمنع الطلب إذا حالة العقار مش متاحة
    const propertyStatus = (property.status || "available").toLowerCase();

    if (["rented", "sold", "active"].includes(propertyStatus)) {
      return res.status(400).json({
        message: `This property is already ${propertyStatus.toUpperCase()} and cannot accept new requests.`,
      });
    }

    // (اختياري) لو بدك تمنع كمان لو في عقد Active لنفس العقار
    const existingActive = await Contract.findOne({
      propertyId,
      status: "active",
    });

    if (existingActive) {
      return res.status(400).json({
        message: "There is already an active contract for this property.",
      });
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

    // 5) إرسال إشعار للمالك
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

    // 6) إشعار للأدمن
    const { notifyAdmins } = await import("../utils/sendNotification.js");
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
      .populate("propertyId", "title price address")
      .populate("unitId", "unitNumber floor rentPrice status")
      .populate("tenantId", "name email phone")
      .populate("landlordId", "name email phone");

    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

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

    // إشعار للمستأجر عند الموافقة
    if (req.body.status === "active" || req.body.status === "rented") {
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
    res
      .status(200)
      .json({ message: "✅ Contract updated successfully", contract });
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