// models/User.js
import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    phone: { type: String },
    profilePicture: { type: String, default: "" }, 

    role: {
      type: String,
      enum: ["tenant", "landlord", "admin"],
      default: "tenant",
    },
    passwordHash: { type: String, required: true },

    resetPasswordToken: String,
    resetPasswordExpires: Date,
  },
  { timestamps: true }
);

export default mongoose.model("User", userSchema);
