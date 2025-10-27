// controllers/adminSettingsController.js
import SystemSetting from "../models/SystemSetting.js";
import { validationResult } from "express-validator";

export const getSystemSettings = async (req, res) => {
  try {
    const settings = await SystemSetting.find({});
    res.status(200).json(settings);
  } catch (error) {
    res.status(500).json({
      message: "❌ Failed to fetch system settings",
      error: error.message,
    });
  }
};

export const updateSystemSetting = async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res
      .status(400)
      .json({ message: "Validation error", errors: errors.array() });
  }

  const { key } = req.params;
  const { value } = req.body;

  try {
    const setting = await SystemSetting.findOne({ key });
    if (!setting) {
      return res
        .status(404)
        .json({ message: `❌ Setting with key '${key}' not found.` });
    }

    let parsedValue = value;
    switch (setting.type) {
      case "boolean":
        parsedValue = value === true || value === "true";
        break;
      case "number":
        parsedValue = Number(value);
        if (isNaN(parsedValue)) {
          return res.status(400).json({
            message: `❌ Invalid value for number type setting '${key}'.`,
          });
        }
        break;
      case "dropdown":
        if (!setting.options || !setting.options.includes(value)) {
          return res.status(400).json({
            message: `❌ Invalid dropdown option '${value}' for setting '${key}'.`,
          });
        }
        break;
    }

    setting.value = parsedValue;
    await setting.save();

    res
      .status(200)
      .json({ message: `✅ Setting '${key}' updated successfully.`, setting });
  } catch (error) {
    res.status(500).json({
      message: `❌ Failed to update system setting '${key}'.`,
      error: error.message,
    });
  }
};

export const initializeDefaultSettings = async () => {
  const defaultSettings = [
    {
      key: "app_title",
      value: "Shaqati Property Management",
      type: "text",
      label: "Application Title",
      category: "General",
      description: "The main title displayed across the application.",
    },
    {
      key: "maintenance_mode",
      value: false,
      type: "boolean",
      label: "Maintenance Mode",
      category: "General",
      description: "Enable or disable the application maintenance mode.",
    },
    {
      key: "support_email",
      value: "support@shaqati.com",
      type: "text",
      label: "Support Email Address",
      category: "General",
      description: "The email address for user support inquiries.",
    },
    {
      key: "default_currency",
      value: "USD",
      type: "text",
      label: "Default Currency",
      category: "General",
      description:
        "The default currency used for payments and property prices.",
    },
    {
      key: "dark_mode_enabled",
      value: false,
      type: "boolean",
      label: "Enable Dark Mode",
      category: "General",
      description: "Toggle dark mode for the entire application UI.",
    },
    {
      key: "default_pagination_limit",
      value: 10,
      type: "number",
      label: "Default Items Per Page",
      category: "General",
      description:
        "The default number of items shown per page in lists (e.g., users, properties).",
    },
    {
      key: "default_date_format",
      value: "yyyy-MM-dd",
      type: "dropdown",
      label: "Default Date Format",
      options: ["yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy/MM/dd HH:mm"],
      category: "General",
      description:
        "The default format for displaying dates across the application.",
    },
    {
      key: "app_logo_url",
      value: "https://example.com/default-logo.png",
      type: "text",
      label: "Application Logo URL",
      category: "General",
      description:
        "URL for the application logo displayed in the header/footer.",
    },
    {
      key: "require_email_verification",
      value: true,
      type: "boolean",
      label: "Require Email Verification",
      category: "User Management",
      description: "Whether new users must verify their email address.",
    },
    {
      key: "default_new_user_role",
      value: "tenant",
      type: "dropdown",
      label: "Default Role for New Users",
      options: ["tenant", "landlord"],
      category: "User Management",
      description: "The default role assigned to new user registrations.",
    },
    {
      key: "max_property_images",
      value: 10,
      type: "number",
      label: "Max Property Images",
      category: "Property Settings",
      description: "Maximum number of images allowed per property listing.",
    },
    {
      key: "default_property_status",
      value: "available",
      type: "dropdown",
      label: "Default Property Status",
      options: ["available", "pending", "rented"],
      category: "Property Settings",
      description: "The default status for new property listings.",
    },
    {
      key: "admin_email_on_new_user",
      value: true,
      type: "boolean",
      label: "Admin Email on New User Registration",
      category: "Notification Settings",
      description: "Send an email to admin when a new user registers.",
    },
    {
      key: "email_on_new_contract",
      value: true,
      type: "boolean",
      label: "Email on New Contract Creation",
      category: "Notification Settings",
      description:
        "Send email notifications to relevant parties on new contract creation.",
    },
  ];

  for (const settingData of defaultSettings) {
    await SystemSetting.findOneAndUpdate(
      { key: settingData.key },
      { $setOnInsert: { ...settingData } },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
  }
  console.log("✅ Default system settings initialized or already present.");
};
