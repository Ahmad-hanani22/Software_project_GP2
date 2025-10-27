// controllers/contractController.js
import Contract from "../models/Contract.js";
import { sendNotification } from "../utils/sendNotification.js";

export const addContract = async (req, res) => {
  try {
    const contract = new Contract(req.body);
    await contract.save();

    await sendNotification({
      userId: contract.tenantId,
      message: "📄 تم إنشاء عقد إيجار جديد معك",
      type: "contract",
      actorId: req.user?._id,
      entityType: "contract",
      entityId: contract._id,
      link: `/contracts/${contract._id}`,
    });

    await sendNotification({
      userId: contract.landlordId,
      message: "🏠 تم تسجيل عقد جديد لعقارك",
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

export const updateContract = async (req, res) => {
  try {
    const contract = await Contract.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
    });

    if (!contract)
      return res.status(404).json({ message: "❌ Contract not found" });

    await sendNotification({
      userId: contract.tenantId,
      message: "📝 تم تعديل بيانات العقد الخاص بك",
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
