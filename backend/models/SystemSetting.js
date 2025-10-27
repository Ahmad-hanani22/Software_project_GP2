// models/SystemSetting.js
import mongoose from "mongoose";

const systemSettingSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      required: true,
      unique: true, 
    },
    value: {
      type: mongoose.Schema.Types.Mixed, 
      required: true,
    },
    type: {
      type: String,
      enum: ["text", "boolean", "dropdown", "number"], 
      required: true,
    },
    label: {
      type: String, 
      required: true,
    },
    options: {
      type: [String], 
      default: undefined, 
    },
    category: {
      type: String, 
      default: "General",
    },
    description: {
      type: String, 
    },
  },
  { timestamps: true }
);

const SystemSetting = mongoose.model("SystemSetting", systemSettingSchema);
export default SystemSetting;
