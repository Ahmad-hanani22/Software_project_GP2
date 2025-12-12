import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    phone: { type: String },
    role: {
      type: String,
      enum: ["tenant", "landlord", "admin"],
      default: "tenant",
    },
    passwordHash: { type: String, required: true },
    profilePicture: { type: String, default: "" },

    // 👇👇 تأكد أن هذه الحقول موجودة 👇👇
    isVerified: { type: Boolean, default: false }, 
    verificationToken: { type: String },           
    
    resetPasswordToken: String,
    resetPasswordExpires: Date,
  },
  { timestamps: true }
);

export default mongoose.model("User", userSchema);