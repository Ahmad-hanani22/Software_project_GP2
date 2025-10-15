import mongoose from "mongoose";

const complaintSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    againstUserId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    type: { type: String, enum: ["tenant", "landlord"] },
    description: String,
    status: {
      type: String,
      enum: ["open", "in_review", "closed"],
      default: "open",
    },
  },
  { timestamps: true }
);

export default mongoose.model("Complaint", complaintSchema);
