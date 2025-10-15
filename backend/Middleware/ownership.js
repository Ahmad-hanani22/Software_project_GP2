import Property from "../models/Property.js";
import Contract from "../models/Contract.js";
import Payment from "../models/Payment.js";
import Complaint from "../models/Complaint.js";
import MaintenanceRequest from "../models/MaintenanceRequest.js";
/* ===========================================================
   🏠 ownsPropertyOrAdmin
   يسمح فقط لمالك العقار أو الأدمن بالوصول (تعديل / حذف)
=========================================================== */
export const ownsPropertyOrAdmin = async (req, res, next) => {
  try {
    const property = await Property.findById(req.params.id).select("ownerId");
    if (!property)
      return res.status(404).json({ message: "Property not found" });

    const isOwner = String(property.ownerId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";

    if (isOwner || isAdmin) return next();

    return res
      .status(403)
      .json({ message: "🚫 Access denied: owner or admin only" });
  } catch (error) {
    return res
      .status(500)
      .json({ message: "Server error", error: error.message });
  }
};

/* ===========================================================
   📄 isContractPartyOrAdmin
   يسمح فقط لطرفي العقد (المالك أو المستأجر) أو الأدمن بالوصول
=========================================================== */
export const isContractPartyOrAdmin = async (req, res, next) => {
  try {
    // نحاول التقاط contractId من عدة احتمالات (params / query / body)
    const contractId =
      req.params.id || req.params.contractId || req.body.contractId;

    if (!contractId)
      return res
        .status(400)
        .json({ message: "Contract ID is required for this action" });

    const contract = await Contract.findById(contractId).select(
      "tenantId landlordId"
    );
    if (!contract)
      return res.status(404).json({ message: "Contract not found" });

    const isTenant = String(contract.tenantId) === String(req.user._id);
    const isLandlord = String(contract.landlordId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";

    if (isTenant || isLandlord || isAdmin) return next();

    return res.status(403).json({
      message: "🚫 Access denied: only contract parties or admin allowed",
    });
  } catch (error) {
    return res
      .status(500)
      .json({ message: "Server error", error: error.message });
  }
};

export const isPaymentRelatedPartyOrAdmin = async (req, res, next) => {
  try {
    const paymentId = req.params.id || req.params.paymentId;
    if (!paymentId)
      return res.status(400).json({ message: "Payment ID is required" });

    const payment = await Payment.findById(paymentId).populate(
      "contractId",
      "tenantId landlordId"
    );

    if (!payment) return res.status(404).json({ message: "Payment not found" });

    const contract = payment.contractId;
    if (!contract)
      return res.status(404).json({ message: "Linked contract not found" });

    const isTenant = String(contract.tenantId) === String(req.user._id);
    const isLandlord = String(contract.landlordId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";

    if (isTenant || isLandlord || isAdmin) return next();

    return res
      .status(403)
      .json({ message: "🚫 Access denied: payment party or admin only" });
  } catch (error) {
    return res
      .status(500)
      .json({ message: "Server error", error: error.message });
  }
};

/* ✅ يضمن أن المستخدم هو صاحب الشكوى أو أدمن أو المالك المتعلق بها */
export const isComplaintOwnerOrAdmin = async (req, res, next) => {
  try {
    const complaintId = req.params.id || req.body.id;
    const complaint = await Complaint.findById(complaintId).select("userId");
    if (!complaint)
      return res.status(404).json({ message: "Complaint not found" });

    const isOwner = String(complaint.userId) === String(req.user._id);
    const isAdmin = req.user.role === "admin";

    if (isOwner || isAdmin) return next();

    return res
      .status(403)
      .json({ message: "🚫 Access denied: complaint owner or admin only" });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

// ✅ يتحقق إن المستخدم هو صاحب الطلب أو أدمن
export const ownsMaintenanceOrAdmin = async (req, res, next) => {
  try {
    const maintenance = await MaintenanceRequest.findById(req.params.id).select(
      "tenantId"
    );
    if (!maintenance) {
      return res
        .status(404)
        .json({ message: "❌ Maintenance request not found" });
    }

    const isOwner = String(maintenance.tenantId) === String(req.user._id);
    if (isOwner || req.user.role === "admin") return next();

    return res.status(403).json({
      message: "🚫 Access denied: maintenance owner or admin only",
    });
  } catch (err) {
    res.status(500).json({ message: "Server error", error: err.message });
  }
};
