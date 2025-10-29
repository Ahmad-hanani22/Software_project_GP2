// models/Review.js
import mongoose from "mongoose";

const reviewSchema = new mongoose.Schema(
  {
    propertyId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Property",
      required: true,
    },
    reviewerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    rating: {
      type: Number,
      min: 1,
      max: 5,
      required: true,
    },
    comment: {
      type: String,
      required: true,
    },
    adminReply: {
      type: String,
      default: "",
    },
    isVisible: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

const Review = mongoose.model("Review", reviewSchema);
export default Review;