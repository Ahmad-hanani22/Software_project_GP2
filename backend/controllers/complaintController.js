import Complaint from "../models/Complaint.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";

/* =========================================================
 🆕 إنشاء شكوى جديدة (Tenant فقط)
========================================================= */
export const createComplaint = async (req, res) => {
  try {
    // ✅ السماح فقط للمستأجرين بإنشاء شكوى
    if (req.user.role !== "tenant") {
      return res
        .status(403)
        .json({ message: "🚫 Only tenants can submit complaints" });
    }

    const { description, againstUserId } = req.body;

    if (!description) {
      return res
        .status(400)
        .json({ message: "❌ Complaint description is required" });
    }

    // ✅ إنشاء الشكوى
    const complaint = new Complaint({
      userId: req.user._id,
      type: "tenant",
      againstUserId: againstUserId || null,
      description: description.trim(),
      status: "pending",
    });

    await complaint.save();

    // 🔔 إشعارات بعد الإرسال
    // 1️⃣ إشعار للمستخدم نفسه
    await sendNotification({
      userId: req.user._id,
      message: "✅ تم استلام الشكوى الخاصة بك وسيتم مراجعتها قريبًا",
      type: "complaint",
      actorId: req.user._id,
      entityType: "complaint",
      entityId: complaint._id,
      link: `/complaints/${complaint._id}`,
    });

    // 2️⃣ إشعار للأدمن لمتابعة الطلب
    await notifyAdmins({
      message: "🧾 تم استلام شكوى جديدة من أحد المستأجرين",
      type: "complaint",
      actorId: req.user._id,
      entityType: "complaint",
      entityId: complaint._id,
      link: `/admin/complaints/${complaint._id}`,
    });

    res.status(201).json({
      message: "✅ Complaint submitted successfully",
      complaint,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error submitting complaint",
      error: error.message,
    });
  }
};

/* =========================================================
 📄 عرض جميع الشكاوى (Admin فقط)
========================================================= */
export const getAllComplaints = async (req, res) => {
  try {
    if (req.user.role !== "admin") {
      return res
        .status(403)
        .json({ message: "🚫 Only admin can view all complaints" });
    }

    const complaints = await Complaint.find()
      .populate("userId", "name email role")
      .populate("againstUserId", "name email role")
      .sort({ createdAt: -1 });

    res.status(200).json(complaints);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching complaints",
      error: error.message,
    });
  }
};

/* =========================================================
 👤 عرض شكاوى مستخدم معيّن (نفسه أو أدمن)
========================================================= */
export const getUserComplaints = async (req, res) => {
  try {
    const { userId } = req.params;

    // 🔐 السماح فقط لنفس المستخدم أو الأدمن
    if (req.user.role !== "admin" && String(req.user._id) !== String(userId)) {
      return res.status(403).json({
        message: "🚫 You can only view your own complaints",
      });
    }

    const complaints = await Complaint.find({ userId })
      .populate("againstUserId", "name email role")
      .sort({ createdAt: -1 });

    res.status(200).json(complaints);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching user complaints",
      error: error.message,
    });
  }
};

/* =========================================================
 ⚙️ تحديث حالة الشكوى (Admin أو Landlord فقط)
========================================================= */
export const updateComplaintStatus = async (req, res) => {
  try {
    // ✅ السماح فقط للأدمن أو المالك
    if (!["admin", "landlord"].includes(req.user.role)) {
      return res.status(403).json({
        message: "🚫 Only admin or landlord can update complaints",
      });
    }

    const { status } = req.body;
    if (!status) {
      return res
        .status(400)
        .json({ message: "❌ Status field is required to update complaint" });
    }

    const complaint = await Complaint.findById(req.params.id);
    if (!complaint)
      return res.status(404).json({ message: "❌ Complaint not found" });

    complaint.status = status;
    await complaint.save();

    // 🔔 إشعار لصاحب الشكوى
    await sendNotification({
      userId: complaint.userId,
      message: `🔄 تم تحديث حالة الشكوى الخاصة بك إلى: ${complaint.status}`,
      type: "complaint",
      actorId: req.user._id,
      entityType: "complaint",
      entityId: complaint._id,
      link: `/complaints/${complaint._id}`,
    });

    res.status(200).json({
      message: "✅ Complaint status updated successfully",
      complaint,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating complaint status",
      error: error.message,
    });
  }
};

/* =========================================================
 ❌ حذف شكوى (صاحبها أو أدمن فقط)
========================================================= */
export const deleteComplaint = async (req, res) => {
  try {
    const complaint = await Complaint.findById(req.params.id);
    if (!complaint)
      return res.status(404).json({ message: "❌ Complaint not found" });

    // 🔐 تحقق من الصلاحية
    if (
      req.user.role !== "admin" &&
      String(complaint.userId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        message: "🚫 You can only delete your own complaints",
      });
    }

    await complaint.deleteOne();

    res.status(200).json({
      message: "✅ Complaint deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting complaint",
      error: error.message,
    });
  }
};
