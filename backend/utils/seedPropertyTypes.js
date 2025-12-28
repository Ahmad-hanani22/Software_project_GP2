// utils/seedPropertyTypes.js
// Script لتهيئة أنواع العقارات الافتراضية
import mongoose from "mongoose";
import dotenv from "dotenv";
import PropertyType from "../models/PropertyType.js";

dotenv.config();

const defaultPropertyTypes = [
  {
    name: "apartment",
    displayName: "Apartment",
    icon: "apartment",
    order: 1,
    description: "شقة سكنية",
  },
  {
    name: "house",
    displayName: "House",
    icon: "home",
    order: 2,
    description: "منزل",
  },
  {
    name: "villa",
    displayName: "Villa",
    icon: "villa",
    order: 3,
    description: "فيلا",
  },
  {
    name: "office",
    displayName: "Office",
    icon: "business",
    order: 4,
    description: "مكتب",
  },
  {
    name: "shop",
    displayName: "Shop",
    icon: "store",
    order: 5,
    description: "محل تجاري",
  },
];

export const seedPropertyTypes = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("✅ Connected to MongoDB");

    // حذف الأنواع الموجودة (اختياري - يمكنك إزالة هذا السطر إذا أردت الاحتفاظ بالبيانات)
    // await PropertyType.deleteMany({});

    // إضافة الأنواع الافتراضية
    for (const typeData of defaultPropertyTypes) {
      const existingType = await PropertyType.findOne({ name: typeData.name });
      
      if (!existingType) {
        await PropertyType.create(typeData);
        console.log(`✅ Created property type: ${typeData.displayName}`);
      } else {
        console.log(`⏭️  Property type already exists: ${typeData.displayName}`);
      }
    }

    console.log("✅ Property types seeding completed!");
    await mongoose.connection.close();
  } catch (error) {
    console.error("❌ Error seeding property types:", error);
    process.exit(1);
  }
};

// تشغيل الـ script مباشرة إذا تم استدعاؤه من terminal
// Note: يمكنك تشغيله يدوياً: node utils/seedPropertyTypes.js

