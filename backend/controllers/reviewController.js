// controllers/reviewController.js
import Review from "../models/Review.js";
import Contract from "../models/Contract.js";
import Property from "../models/Property.js";
import { sendNotification } from "../utils/sendNotification.js";

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

    const existingReview = await Review.findOne({ userId: req.user._id, propertyId });
    if (existingReview) {
      return res.status(400).json({ message: "You have already reviewed this property." });
    }

    const review = new Review({
      userId: req.user._id,
      propertyId,
      rating,
      comment,
    });
    await review.save();

    const property = await Property.findById(propertyId).select("ownerId title");
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

export const getAllReviews = async (req, res) => {};
export const getReviewsByProperty = async (req, res) => {};
export const updateReview = async (req, res) => {};
export const deleteReview = async (req, res) => {};
