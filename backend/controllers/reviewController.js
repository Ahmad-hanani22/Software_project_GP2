// controllers/reviewController.js
import Review from "../models/Review.js";
import Contract from "../models/Contract.js";
import Property from "../models/Property.js";
import { sendNotificationToUser } from "../utils/sendNotification.js";

export const createReview = async (req, res) => {
  try {
    if (req.user.role !== "tenant") {
      return res.status(403).json({ message: "🚫 Only tenants can add reviews" });
    }
    const { propertyId, rating, comment } = req.body;
    if (!propertyId || !rating) {
      return res.status(400).json({ message: "❌ propertyId and rating are required" });
    }
    const hasContract = await Contract.findOne({ tenantId: req.user._id, propertyId });
    if (!hasContract) {
      return res.status(403).json({ message: "🚫 You must have a contract for this property" });
    }
    const existingReview = await Review.findOne({ reviewerId: req.user._id, propertyId });
    if (existingReview) {
      return res.status(400).json({ message: "You have already reviewed this property." });
    }
    const review = new Review({ reviewerId: req.user._id, propertyId, rating, comment });
    await review.save();
    const property = await Property.findById(propertyId).select("ownerId title");
    if (property?.ownerId) {
      await sendNotificationToUser({
        userId: property.ownerId,
        message: `⭐ تم إضافة تقييم جديد على عقارك "${property.title}"`,
        type: "review",
        actorId: req.user._id,
        entityType: "property",
        entityId: propertyId,
        link: `/properties/${propertyId}`,
      });
    }
    res.status(201).json({ message: "✅ Review added successfully", review });
  } catch (error) {
    res.status(500).json({ message: "❌ Error adding review", error: error.message });
  }
};

export const getReviews = async (req, res) => {
  try {
    const reviews = await Review.find()
      .populate("reviewerId", "name email")
      .populate("propertyId", "title")
      .sort({ createdAt: -1 });
    res.status(200).json(reviews);
  } catch (error) {
    res.status(500).json({ message: "Error fetching reviews", error: error.message });
  }
};

export const getReviewsByProperty = async (req, res) => {
  try {
    const { propertyId } = req.params;
    const reviews = await Review.find({ propertyId, isVisible: true }) // Only fetch visible reviews
      .populate("reviewerId", "name email")
      .sort({ createdAt: -1 });
    res.status(200).json(reviews);
  } catch (error) {
    res.status(500).json({ message: "❌ Error fetching property reviews", error: error.message });
  }
};

export const updateReview = async (req, res) => {
  try {
    const review = await Review.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!review) return res.status(404).json({ message: "Review not found" });

    res.status(200).json({ message: "✅ Review updated successfully", review });
  } catch (error) {
     res.status(500).json({ message: "❌ Error updating review", error: error.message });
  }
};

export const deleteReview = async (req, res) => {
    try {
        const review = await Review.findByIdAndDelete(req.params.id);
        if(!review) return res.status(404).json({ message: "Review not found" });
        res.status(200).json({ message: "🗑️ Review deleted successfully" });
    } catch (error) {
        res.status(500).json({ message: "❌ Error deleting review", error: error.message });
    }
};