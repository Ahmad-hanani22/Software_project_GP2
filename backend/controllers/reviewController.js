// controllers/reviewController.js
import Review from "../models/Review.js";
import Contract from "../models/Contract.js";
import Property from "../models/Property.js";
import { sendNotification } from "../utils/sendNotification.js";

/* =========================================================
 📝 إضافة تقييم جديد (Tenant فقط)
========================================================= */
export const addReview = async (req, res) => {
  try {
    if (req.user.role !== "tenant") {
      return res
        .status(403)
        .json({ message: "🚫 Only tenants can add reviews" });
    }

    const { propertyId, rating, comment } = req.body;

    if (!propertyId || !rating) {
      return res
        .status(400)
        .json({ message: "❌ propertyId and rating are required" });
    }

    // ✅ تحقق أن المستخدم مستأجر فعلي في عقد لهذا العقار
    const hasContract = await Contract.findOne({
      tenantId: req.user._id,
      propertyId,
    });

    if (!hasContract) {
      return res
        .status(403)
        .json({ message: "🚫 You must have a contract for this property" });
    }

    // ✅ إنشاء التقييم
    const review = new Review({
      userId: req.user._id,
      propertyId,
      rating,
      comment,
    });

    await review.save();

    // ✅ إشعار مالك العقار
    const property = await Property.findById(propertyId).select(
      "ownerId title"
    );
    if (property?.ownerId) {
      await sendNotification({
        userId: property.ownerId,
        message: `⭐ تم إضافة تقييم جديد على عقارك "${property.title}"`,
        type: "review",
        actorId: req.user._id,
        entityType: "property",
        entityId: propertyId,
        link: `/properties/${propertyId}`,
      });
    }

    res.status(201).json({
      message: "✅ Review added successfully",
      review,
    });
  } catch (error) {
    console.error("❌ Error adding review:", error);
    res
      .status(500)
      .json({ message: "❌ Error adding review", error: error.message });
  }
};

/* =========================================================
 📋 عرض جميع التقييمات
========================================================= */
export const getAllReviews = async (req, res) => {
  try {
    const reviews = await Review.find()
      .populate("userId", "name email")
      .populate("propertyId", "title address");

    res.status(200).json(reviews);
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error fetching reviews", error: error.message });
  }
};

/* =========================================================
 🏠 عرض التقييمات لعقار محدد
========================================================= */
export const getReviewsByProperty = async (req, res) => {
  try {
    const { propertyId } = req.params;

    const reviews = await Review.find({ propertyId })
      .populate("userId", "name")
      .sort({ createdAt: -1 });

    res.status(200).json(reviews);
  } catch (error) {
    res
      .status(500)
      .json({
        message: "❌ Error fetching property reviews",
        error: error.message,
      });
  }
};

/* =========================================================
 ✏️ تعديل تقييم (صاحب التقييم أو أدمن فقط)
========================================================= */
export const updateReview = async (req, res) => {
  try {
    const review = await Review.findById(req.params.id);

    if (!review)
      return res.status(404).json({ message: "❌ Review not found" });

    if (
      req.user.role !== "admin" &&
      String(review.userId) !== String(req.user._id)
    ) {
      return res
        .status(403)
        .json({ message: "🚫 Not allowed to edit this review" });
    }

    review.rating = req.body.rating ?? review.rating;
    review.comment = req.body.comment ?? review.comment;

    await review.save();

    res.status(200).json({
      message: "✅ Review updated successfully",
      review,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error updating review", error: error.message });
  }
};

/* =========================================================
 ❌ حذف تقييم (صاحب التقييم أو أدمن فقط)
========================================================= */
export const deleteReview = async (req, res) => {
  try {
    const review = await Review.findById(req.params.id);

    if (!review)
      return res.status(404).json({ message: "❌ Review not found" });

    if (
      req.user.role !== "admin" &&
      String(review.userId) !== String(req.user._id)
    ) {
      return res
        .status(403)
        .json({ message: "🚫 Not allowed to delete this review" });
    }

    await review.deleteOne();

    res.status(200).json({ message: "🗑️ Review deleted successfully" });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error deleting review", error: error.message });
  }
};
