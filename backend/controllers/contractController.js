// controllers/contractController.js
import Contract from "../models/Contract.js";
import { sendNotification } from "../utils/sendNotification.js";

// 1. إنشاء عقد مباشر (للمالك أو الأدمن)
export const addContract = async (req, res) => {
  try {
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
    const { propertyId, landlordId, rentAmount } = req.body;
    const tenantId = req.user._id;

    // إنشاء عقد مبدئي بحالة 'pending'
    const newContract = new Contract({
      propertyId,
      tenantId,
      landlordId,
      rentAmount,
      startDate: new Date(), // تاريخ مبدئي
      endDate: new Date(new Date().setFullYear(new Date().getFullYear() + 1)), // سنة افتراضية
      status: "pending", // 👈 الحالة معلقة بانتظار موافقة المالك
    });

    await newContract.save();

    // هذا الجزء في كودك (controllers/contractController.js) صحيح تماماً
await sendNotification({
  recipients: [landlordId],
  message: `New Rental Request! Click to approve contract.`,
  title: "Contract Request",
  type: "contract_request", // 👈 هذا النوع مهم جداً للفرونت إند
  actorId: tenantId,
  entityType: "contract",
  entityId: newContract._id, // ✅ هنا ربطنا الإشعار بالعقد
  link: `/contracts/${newContract._id}`
});

    res.status(201).json({ 
      message: "Request sent successfully. Contract created (pending approval).", 
      contract: newContract 
    });

  } catch (error) {
    console.error("Error requesting contract:", error);
    res.status(500).json({ message: "Error requesting contract", error: error.message });
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
    const contract = await Contract.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });

    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    // إشعار للمستأجر عند التحديث (مثلاً عند الموافقة)
    await sendNotification({
      recipients: [contract.tenantId],
      message: `📝 Contract status updated to: ${contract.status}`,
      title: "Contract Updated",
      type: "contract",
      actorId: req.user?._id,
      entityType: "contract",
      entityId: contract._id,
    });

    res
      .status(200)
      .json({ message: "✅ Contract updated successfully", contract });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error updating contract", error: error.message });
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