// utils/seedPropertyTypes.js
import mongoose from "mongoose";
import PropertyType from "../models/PropertyType.js";

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
    // ⚠️ ملاحظة: لا نقوم بفتح الاتصال هنا لأن server.js قام بذلك بالفعل
    // ولا نقوم بإغلاقه حتى لا ينقطع الاتصال عن السيرفر

    for (const typeData of defaultPropertyTypes) {
      const existingType = await PropertyType.findOne({ name: typeData.name });

      if (!existingType) {
        await PropertyType.create(typeData);
        console.log(`✅ Created property type: ${typeData.displayName}`);
      } else {
        // تم التعليق لتخفيف السجلات في الـ Console
        // console.log(`⏭️  Property type already exists: ${typeData.displayName}`);
      }
    }

    console.log("✅ Property types seeding completed!");

    // ❌ تم حذف سطر mongoose.connection.close() لمنع فصل السيرفر
  } catch (error) {
    console.error("❌ Error seeding property types:", error);
    // ❌ تم حذف process.exit(1) حتى لا يتوقف السيرفر في حال حدوث خطأ بسيط هنا
  }
};