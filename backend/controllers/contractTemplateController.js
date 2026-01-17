// controllers/contractTemplateController.js
import ContractTemplate from "../models/ContractTemplate.js";

// 1. إنشاء قالب عقد جديد
export const addContractTemplate = async (req, res) => {
  try {
    const userId = req.user._id;
    const templateData = {
      ...req.body,
      createdBy: userId,
    };

    // إذا كان القالب هو الافتراضي، قم بإلغاء الافتراضي من القوالب الأخرى
    if (templateData.isDefault) {
      await ContractTemplate.updateMany(
        { isDefault: true },
        { $set: { isDefault: false } }
      );
    }

    const template = new ContractTemplate(templateData);
    await template.save();

    res.status(201).json({
      message: "✅ Contract template created successfully",
      template,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error creating contract template",
      error: error.message,
    });
  }
};

// 2. جلب جميع قوالب العقود
export const getAllContractTemplates = async (req, res) => {
  try {
    const { isActive, isDefault } = req.query;
    const query = {};

    if (isActive !== undefined) {
      query.isActive = isActive === "true";
    }
    if (isDefault !== undefined) {
      query.isDefault = isDefault === "true";
    }

    const templates = await ContractTemplate.find(query)
      .populate("createdBy", "name email")
      .sort({ createdAt: -1 });

    res.status(200).json(templates);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching contract templates",
      error: error.message,
    });
  }
};

// 3. جلب قالب عقد محدد
export const getContractTemplateById = async (req, res) => {
  try {
    const template = await ContractTemplate.findById(req.params.id).populate(
      "createdBy",
      "name email"
    );

    if (!template) {
      return res.status(404).json({ message: "Contract template not found" });
    }

    res.status(200).json(template);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching contract template",
      error: error.message,
    });
  }
};

// 4. تحديث قالب عقد
export const updateContractTemplate = async (req, res) => {
  try {
    const template = await ContractTemplate.findById(req.params.id);

    if (!template) {
      return res.status(404).json({ message: "Contract template not found" });
    }

    // إذا كان القالب هو الافتراضي، قم بإلغاء الافتراضي من القوالب الأخرى
    if (req.body.isDefault && !template.isDefault) {
      await ContractTemplate.updateMany(
        { _id: { $ne: template._id }, isDefault: true },
        { $set: { isDefault: false } }
      );
    }

    Object.assign(template, req.body);
    await template.save();

    res.status(200).json({
      message: "✅ Contract template updated successfully",
      template,
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating contract template",
      error: error.message,
    });
  }
};

// 5. حذف قالب عقد
export const deleteContractTemplate = async (req, res) => {
  try {
    const template = await ContractTemplate.findById(req.params.id);

    if (!template) {
      return res.status(404).json({ message: "Contract template not found" });
    }

    // منع حذف القالب الافتراضي
    if (template.isDefault) {
      return res.status(400).json({
        message: "Cannot delete the default contract template",
      });
    }

    await ContractTemplate.findByIdAndDelete(req.params.id);

    res.status(200).json({
      message: "✅ Contract template deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting contract template",
      error: error.message,
    });
  }
};

// 6. جلب القالب الافتراضي
export const getDefaultContractTemplate = async (req, res) => {
  try {
    const template = await ContractTemplate.findOne({ isDefault: true });

    if (!template) {
      // إذا لم يكن هناك قالب افتراضي، أرجع أول قالب نشط
      const firstActiveTemplate = await ContractTemplate.findOne({
        isActive: true,
      });
      if (firstActiveTemplate) {
        return res.status(200).json(firstActiveTemplate);
      }
      return res.status(404).json({
        message: "No default contract template found",
      });
    }

    res.status(200).json(template);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching default contract template",
      error: error.message,
    });
  }
};

// 7. زيادة عدد استخدامات القالب
export const incrementTemplateUsage = async (templateId) => {
  try {
    await ContractTemplate.findByIdAndUpdate(templateId, {
      $inc: { usageCount: 1 },
      $set: { lastUsedAt: new Date() },
    });
  } catch (error) {
    console.error("Error incrementing template usage:", error);
  }
};
