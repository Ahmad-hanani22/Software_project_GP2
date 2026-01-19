// controllers/propertyController.js
import Property from "../models/Property.js";
import Unit from "../models/Unit.js";
import PropertyHistory from "../models/PropertyHistory.js";
import { sendNotification, notifyAdmins } from "../utils/sendNotification.js";

export const addProperty = async (req, res) => {
  try {
    if (!["landlord", "admin"].includes(req.user.role)) {
      return res
        .status(403)
        .json({ message: "🚫 Only landlord or admin can add properties" });
    }

    // ✅ استخراج قائمة الشقق من req.body إذا كانت موجودة (للعمارات)
    const { units, ...propertyData } = req.body;

    // ✅ التأكد من أن الملاك (landlords) لا يمكنهم تجاوز حالة الموافقة
    // ✅ فقط الأدمن يمكنه إنشاء عقار بحالة available مباشرة
    // ✅ هذا يضمن أن عقارات الملاك لن تظهر في الصفحة الرئيسية حتى يوافق الأدمن عليها
    if (req.user.role === 'landlord') {
      // إزالة status و verified من propertyData إذا كان المالك يحاول تعيينهما
      // ✅ هذا يمنع الملاك من تعيين status: 'available' أو verified: true مباشرة
      delete propertyData.status;
      delete propertyData.verified;
      // ✅ سيكون status: 'pending_approval' و verified: false افتراضياً من الموديل
      // ✅ العقار لن يظهر في getAllProperties حتى يوافق الأدمن عليه
    } else if (req.user.role === 'admin') {
      // الأدمن يمكنه تعيين status و verified مباشرة
      // إذا لم يتم تحديدهما، استخدم القيم الافتراضية
      if (!propertyData.status) {
        propertyData.status = 'pending_approval';
      }
      if (propertyData.verified === undefined) {
        propertyData.verified = false;
      }
    }

    const property = new Property({
      ...propertyData,
      ownerId: req.user._id,
    });
    await property.save();

    // ✅ إنشاء الشقق (Units) إذا كان العقار من نوع apartment وكانت هناك شقق محددة
    // ✅ كل Unit له بياناته الخاصة (Encapsulation)
    if (property.type === 'apartment' && units && Array.isArray(units) && units.length > 0) {
      try {
        const createdUnits = [];
        for (const unitData of units) {
          // ✅ التأكد من أن كل Unit له بياناته الخاصة
          // استخدام البيانات من unitData أولاً، ثم القيم الافتراضية من Property
          const unit = new Unit({
            propertyId: property._id,
            // ✅ بيانات خاصة بكل Unit
            unitNumber: unitData.unitNumber || `Unit ${createdUnits.length + 1}`, // رقم الشقة الخاص
            floor: unitData.floor ?? ((createdUnits.length % 4) + 1), // طابق خاص
            rooms: unitData.rooms ?? property.bedrooms ?? 1, // عدد غرف خاص
            area: unitData.area ?? property.area ?? 0, // مساحة خاصة
            rentPrice: unitData.rentPrice ?? unitData.price ?? property.price ?? 0, // سعر خاص
            bathrooms: unitData.bathrooms ?? property.bathrooms ?? 1, // حمامات خاصة
            status: unitData.status ?? 'vacant', // حالة خاصة
            description: unitData.description || '', // وصف خاص
            images: unitData.images || [], // صور خاصة
            amenities: unitData.amenities || [], // مميزات خاصة
          });
          await unit.save();
          createdUnits.push(unit._id);
        }
        
        // تحديث displayedUnits إذا كانت هناك شقق محددة
        if (property.unitsDisplayMode === 'selected' && createdUnits.length > 0) {
          property.displayedUnits = createdUnits;
          await property.save();
        }
      } catch (unitError) {
        console.error("⚠️ Error creating units for apartment:", unitError);
        // لا نفشل عملية إنشاء العقار إذا فشل إنشاء الشقق
      }
    }

    // ✅ إنشاء سجل تاريخ تلقائياً
    try {
      await PropertyHistory.create({
        propertyId: property._id,
        action: "created",
        performedBy: req.user._id,
        description: `Property "${property.title}" was created`,
      });
    } catch (historyError) {
      console.error("⚠️ Error creating property history:", historyError);
      // لا نفشل العملية إذا فشل إنشاء التاريخ
    }

    await notifyAdmins({
      title: "🏠 عقار جديد",
      message: `تم إضافة عقار جديد من ${req.user.role === "landlord" ? "مالك" : "أدمن"
        }`,
      type: "property",
      actorId: req.user._id,
      entityType: "property",
      entityId: property._id,
      link: `/admin/properties/${property._id}`,
    });

    res.status(201).json({
      message: "✅ Property added successfully",
      property,
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "❌ Error adding property", error: error.message });
  }
};

export const getAllProperties = async (req, res) => {
  try {
    console.log("🔹 Fetching all properties...");
    const { type, operation, city, minPrice, maxPrice } = req.query;

    // ✅ فقط عرض العقارات الموافق عليها من الأدمن (available و verified)
    // ✅ العقارات التي يضيفها الملاك (landlords) لن تظهر هنا حتى يوافق الأدمن عليها
    // ✅ هذا يشمل أيضاً الشقق (units) - لن تظهر حتى يوافق الأدمن على العقار الأصلي
    const query = {
      status: 'available',
      verified: true
    };

    if (type) query.type = type;
    if (operation) query.operation = operation;
    if (city) query.city = new RegExp(city, "i");

    if (minPrice || maxPrice) {
      query.price = {};
      if (minPrice) query.price.$gte = Number(minPrice);
      if (maxPrice) query.price.$lte = Number(maxPrice);
    }

    console.log("🔹 Query:", JSON.stringify(query));

    const properties = await Property.find(query)
      .populate("ownerId", "name email")
      .sort({ createdAt: -1 })
      .lean();

    console.log(`✅ Found ${properties.length} approved properties`);
    
    // ✅ إضافة الوحدات المتوفرة للـ apartments كعقارات منفصلة
    // ✅ فقط إذا كان العقار الأصلي موافق عليه من الأدمن
    // ✅ هذا يضمن أن الشقق (units) لن تظهر حتى يوافق الأدمن على العقار الأصلي
    const propertiesWithUnits = [];
    
    for (const property of properties) {
      // ✅ إذا كان العقار من نوع apartment، أضف الوحدات المتوفرة (vacant) كعقارات
      // ✅ فقط إذا كان العقار الأصلي موافق عليه (status: 'available' و verified: true)
      // ✅ الشقق لن تظهر في الصفحة الرئيسية حتى يوافق الأدمن على العقار الأصلي
      if (property.type === 'apartment' && property.status === 'available' && property.verified === true) {
        const availableUnits = await Unit.find({
          propertyId: property._id,
          status: 'vacant' // ✅ فقط الشقق المتوفرة
        }).lean();
        
        // ✅ تحويل كل وحدة إلى تنسيق property للتصفح
        for (const unit of availableUnits) {
          const unitAsProperty = {
            ...property, // نسخ بيانات العقار الأساسية
            _id: unit._id, // ✅ ID الوحدة
            __isUnit: true, // ✅ علامة لتحديد أنها وحدة
            __parentPropertyId: property._id.toString(), // ✅ ID العقار الأصلي
            title: `${property.title || 'Unit'} - ${unit.unitNumber}`, // ✅ عنوان شامل رقم الوحدة
            price: unit.rentPrice || property.price || 0, // ✅ سعر الوحدة
            bedrooms: unit.rooms || property.bedrooms || 0, // ✅ عدد الغرف
            bathrooms: unit.bathrooms || property.bathrooms || 0, // ✅ عدد الحمامات
            area: unit.area || property.area || 0, // ✅ المساحة
            images: (unit.images && unit.images.length > 0) ? unit.images : (property.images || []), // ✅ صور الوحدة أو العقار
            description: unit.description || property.description || '', // ✅ وصف الوحدة
            amenities: unit.amenities || property.amenities || [], // ✅ مميزات الوحدة
            unitNumber: unit.unitNumber, // ✅ رقم الوحدة
            floor: unit.floor, // ✅ الطابق
            status: 'available', // ✅ حالة متاحة (لأنها vacant)
          };
          propertiesWithUnits.push(unitAsProperty);
        }
        
        // ✅ أيضاً أضف العقار نفسه إذا لم يكن لديه وحدات أو إذا كان هناك شقق مشغولة
        // (يمكنك تعطيل هذا السطر إذا كنت تريد عرض الشقق فقط)
        // propertiesWithUnits.push(property);
      } else {
        // ✅ العقارات غير apartments تُضاف كما هي
        propertiesWithUnits.push(property);
      }
    }

    console.log(`✅ Total items (properties + units): ${propertiesWithUnits.length}`);
    
    // Debug: Check first property ownerId structure
    if (propertiesWithUnits.length > 0) {
      console.log(`🔍 First item ownerId:`, propertiesWithUnits[0].ownerId);
    }
    
    res.status(200).json(propertiesWithUnits);
  } catch (error) {
    console.error("❌ Error fetching public properties:", error);
    res.status(500).json({
      message: "Error fetching properties",
      error: error.message, // Send error details to client for debugging
    });
  }
};


export const getPropertyById = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id).populate(
      "ownerId",
      "name email phone"
    );
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });
    res.status(200).json(property);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching property",
      error: error.message,
    });
  }
};

export const getPropertiesByOwner = async (req, res) => {
  try {
    const { ownerId } = req.params;
    if (req.user.role !== "admin" && String(req.user._id) !== String(ownerId)) {
      return res.status(403).json({
        message: "🚫 You can only view your own properties",
      });
    }

    const properties = await Property.find({ ownerId }).sort({ createdAt: -1 });
    res.status(200).json(properties);
  } catch (error) {
    res.status(500).json({
      message: "❌ Error fetching owner properties",
      error: error.message,
    });
  }
};

export const updateProperty = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id);
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });

    if (
      req.user.role !== "admin" &&
      String(property.ownerId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        message: "🚫 You can only update your own properties",
      });
    }

    // ✅ استخراج قائمة الشقق من req.body إذا كانت موجودة (للعمارات)
    const { units, ...propertyData } = req.body;

    // ✅ حفظ التغييرات لتحديد ما تم تعديله
    const oldPrice = property.price;
    const oldStatus = property.status;
    
    Object.assign(property, propertyData);
    await property.save();

    // ✅ إنشاء سجل تاريخ تلقائياً للتغييرات
    try {
      const changes = {};
      let action = "updated";
      
      if (oldPrice !== property.price) {
        changes.price = { from: oldPrice, to: property.price };
        action = "price_changed";
      }
      
      if (oldStatus !== property.status) {
        changes.status = { from: oldStatus, to: property.status };
        action = "status_changed";
      }
      
      await PropertyHistory.create({
        propertyId: property._id,
        action: action,
        performedBy: req.user._id,
        changes: Object.keys(changes).length > 0 ? changes : propertyData,
        description: `Property "${property.title}" was updated`,
      });
    } catch (historyError) {
      console.error("⚠️ Error creating property history:", historyError);
      // لا نفشل العملية إذا فشل إنشاء التاريخ
    }

    // ✅ تحديث/إنشاء الشقق إذا كان العقار من نوع apartment وكانت هناك شقق محددة
    if (property.type === 'apartment' && units && Array.isArray(units)) {
      try {
        // ملاحظة: التحديث الكامل للشقق يجب أن يتم من خلال وحدة إدارة الشقق
        // هنا نتعامل فقط مع الحالات الخاصة (مثل إضافة شقق جديدة)
        // الشقق الموجودة يتم تحديثها من خلال UnitController
      } catch (unitError) {
        console.error("⚠️ Error updating units for apartment:", unitError);
      }
    }

    await notifyAdmins({
      title: "✏️ تحديث عقار",
      message: `تم تعديل تفاصيل عقار (${property.title}) من ${req.user.role}`,
      type: "property",
      actorId: req.user._id,
      entityType: "property",
      entityId: property._id,
      link: `/admin/properties/${property._id}`,
    });

    res.status(200).json({ message: "✅ Property updated", property });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error updating property",
      error: error.message,
    });
  }
};

export const deleteProperty = async (req, res) => {
  try {
    const property = await Property.findById(req.params.id);
    if (!property)
      return res.status(404).json({ message: "❌ Property not found" });

    if (
      req.user.role !== "admin" &&
      String(property.ownerId) !== String(req.user._id)
    ) {
      return res.status(403).json({
        message: "🚫 You can only delete your own properties",
      });
    }

    await property.deleteOne();

    await notifyAdmins({
      title: "🗑️ حذف عقار",
      message: `تم حذف عقار (${property.title}) من النظام`,
      type: "property",
      actorId: req.user._id,
      entityType: "property",
      entityId: property._id,
      link: `/admin/properties`,
    });

    res.status(200).json({ message: "🗑️ Property deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "❌ Error deleting property",
      error: error.message,
    });
  }
};
