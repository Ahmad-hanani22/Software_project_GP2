// controllers/contractController.js
import Contract from "../models/Contract.js";
import { sendNotification } from "../utils/sendNotification.js";
import Property from "../models/Property.js";

export const addContract = async (req, res) => {
  try {
    const { propertyId } = req.body;

    if (propertyId) {
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
      message: `New Rental Request! Click to approve contract.`,
      title: "Contract Request",
      type: "contract_request",
      actorId: tenantId,
      entityType: "contract",
      entityId: newContract._id,
      link: `/contracts/${newContract._id}`,
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
      .populate("propertyId", "title price")
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
    if (req.body.status === "active") {
      // 1) نتأكد ما في عقد Active آخر لنفس العقار
      const anotherActive = await Contract.findOne({
        _id: { $ne: contract._id },
        propertyId: contract.propertyId,
        status: "active",
      });

      if (anotherActive) {
        return res.status(400).json({
          message:
            "Another active contract already exists for this property. Cannot activate this contract.",
        });
      }

      // 2) نحدد حالة العقار (مؤجر ولا مباع)
      const newStatus =
        contract.rentAmount && contract.rentAmount > 0 ? "rented" : "sold";

      await Property.findByIdAndUpdate(contract.propertyId, {
        status: newStatus,
      });
    }

    // إشعار للمستأجر
    await sendNotification({
      recipients: [contract.tenantId],
      message: `✅ Your contract has been approved and is now Active!`,
      title: "Contract Approved",
      type: "contract",
      actorId: req.user?._id,
      entityType: "contract",
      entityId: contract._id,
    });

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