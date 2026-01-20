// controllers/aiController.js
import asyncHandler from "express-async-handler";
import { protect } from "../middleware/authMiddleware.js";
import { chatWithAIProvider, checkAIProviderHealth, getAIProvider } from "../utils/aiProviders.js";
import User from "../models/User.js";
import Property from "../models/Property.js";
import UserProfile from "../models/UserProfile.js";
import UserBehavior from "../models/UserBehavior.js";
import Contract from "../models/Contract.js";
import Payment from "../models/Payment.js";
import MaintenanceRequest from "../models/MaintenanceRequest.js";
import Complaint from "../models/Complaint.js";
import Unit from "../models/Unit.js";
import Building from "../models/Building.js";
import Deposit from "../models/Deposit.js";
import Expense from "../models/Expense.js";
import Invoice from "../models/Invoice.js";
import Review from "../models/Review.js";
import Notification from "../models/Notification.js";
import Chat from "../models/Chat.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * قراءة ملفات ai_knowledge ودمجها في نص واحد
 */
function loadKnowledgeFiles() {
  const knowledgeDir = path.join(__dirname, "../../ai_knowledge");
  const knowledgeFiles = [
    "README.md",
    "API_ROUTES.md",
    "DB_SCHEMA.md",
    "FOLDER_MAP.md",
    "SCREENS_AND_FEATURES.md", // ✅ ملف جديد - الشاشات والميزات
    "TROUBLESHOOTING.md",      // ✅ ملف جديد - حل المشاكل
    "PROJECT_DETAILS.md",     // ✅ ملف جديد - تفاصيل المشروع
  ];

  let knowledgeContent = "";

  knowledgeFiles.forEach((file) => {
    const filePath = path.join(knowledgeDir, file);
    try {
      if (fs.existsSync(filePath)) {
        const content = fs.readFileSync(filePath, "utf8");
        knowledgeContent += `\n\n=== ${file} ===\n${content}\n`;
      } else {
        console.warn(`⚠️  ملف ${file} غير موجود`);
      }
    } catch (error) {
      console.warn(`⚠️  لم يتم قراءة ملف ${file}:`, error.message);
    }
  });

  return knowledgeContent;
}

/**
 * Role-Aware System Prompt
 */
function getUserRolePrompt(role, userId) {
  const basePrompt = `أنت مساعد ذكي متخصص في نظام SHAQATI لإدارة العقارات.
المشروع: Flutter + Node.js لإدارة العقارات في فلسطين.

**دورك الحالي: ${role.toUpperCase()}**`;

  switch (role) {
    case "tenant":
      return `${basePrompt}

**مهمتك كمساعد للمستأجر:**
- اقتراح عقارات مناسبة بناءً على الميزانية والموقع
- شرح نظام العقود والدفعات
- مساعدة في طلبات الصيانة
- مقارنة العقارات والمساعدة في اتخاذ القرار

**الأدوات المتاحة:**
- getTopViewedProperties: العقارات الأكثر مشاهدة
- getRecommendedProperties: اقتراحات بناءً على الميزانية والمدينة
- checkAvailability: فحص توفر عقار
- calculateRentEstimate: حساب تقدير الإيجار
- getUserPreferences: تفضيلات المستخدم

**مثال على الإجابة الواضحة (Explainable AI):**
"اقترحت هذا العقار لأن:
1. السعر ضمن ميزانيتك
2. في المدينة المفضلة لديك
3. متاح للإيجار فوراً"`;

    case "landlord":
      return `${basePrompt}

**مهمتك كمساعد للمالك:**
- تحليل أداء العقارات
- اقتراح تسعير ذكي
- تحليل الطلب في المنطقة
- إدارة العقود والدفعات
- تحسين عرض العقارات

**الأدوات المتاحة:**
- getPropertyStats: إحصائيات عقار
- getRecommendedProperties: تحليل السوق
- checkAvailability: إدارة التوفر
- calculateRentEstimate: تحليل التسعير`;

    case "admin":
      return `${basePrompt}

**مهمتك كمساعد للأدمن:**
- مراقبة نشاط النظام
- تحليل الإحصائيات
- كشف أنماط غير طبيعية
- دعم المستخدمين
- إدارة الإعدادات`;

    default:
      return basePrompt;
  }
}

// ===========================
// Intent Engine Helpers
// ===========================

// Simple intent parser for Arabic/English mixed questions
function parseIntent(question) {
  const q = (question || "").toLowerCase();

  // Map-related property search
  if (q.includes("خريطة") || q.includes("الخريطة") || q.includes("map")) {
    return {
      intent: "search_properties_on_map",
      filters: extractPropertyFilters(q),
    };
  }

  // Contracts expiring soon
  if (
    (q.includes("عقود") || q.includes("عقد")) &&
    (q.includes("تنتهي") || q.includes("ينتهي") || q.includes("هذا الشهر") || q.includes("الشهر"))
  ) {
    return { intent: "contracts_expiring_soon" };
  }

  // Late payments
  if (
    (q.includes("متأخر") || q.includes("متاخر") || q.includes("متأخرة") || q.includes("متاخره")) &&
    (q.includes("دفع") || q.includes("الدفعات") || q.includes("دفعات") || q.includes("ايجار") || q.includes("إيجار"))
  ) {
    return { intent: "late_payments" };
  }

  // List all contracts (with optional status)
  if (
    q.includes("عقودي") ||
    (q.includes("عقود") && (q.includes("الكل") || q.includes("الفعالة") || q.includes("المنتهية") || q.includes("الجديدة")))
  ) {
    return { intent: "list_contracts" };
  }

  // List all payments
  if (
    q.includes("دفعاتي") ||
    q.includes("مدفوعاتي") ||
    (q.includes("الدفعات") && !q.includes("متأخر")) ||
    q.includes("المدفوعات")
  ) {
    return { intent: "list_payments" };
  }

  // List maintenance requests
  if (
    q.includes("طلبات الصيانة") ||
    q.includes("طلب صيانة") ||
    (q.includes("الصيانة") && (q.includes("عندي") || q.includes("الخاصة بي")))
  ) {
    return { intent: "list_maintenance" };
  }

  // List complaints
  if (
    q.includes("شكاوي") ||
    q.includes("شكاوى") ||
    q.includes("شكوى") ||
    q.includes("complaints")
  ) {
    return { intent: "list_complaints" };
  }

  // List notifications
  if (
    q.includes("إشعاراتي") ||
    q.includes("اشعاراتي") ||
    q.includes("الإشعارات") ||
    q.includes("الاشعارات")
  ) {
    return { intent: "list_notifications" };
  }

  // List financial operations (expenses, deposits, invoices)
  if (
    q.includes("مصاريف") ||
    q.includes("نفقاتي") ||
    q.includes("الودائع") ||
    q.includes("وديعة") ||
    q.includes("فواتير") ||
    q.includes("الفواتير")
  ) {
    return { intent: "list_financial" };
  }

  // Dashboard / statistics summary
  if (
    q.includes("ملخص") ||
    q.includes("إحصائيات") ||
    q.includes("احصائيات") ||
    q.includes("dashboard") ||
    q.includes("داشبورد")
  ) {
    return { intent: "dashboard_summary" };
  }

  // Property search (without explicit map)
  if (
    q.includes("شقة") ||
    q.includes("شقق") ||
    q.includes("عقار") ||
    q.includes("عقارات") ||
    q.includes("للإيجار") ||
    q.includes("ايجار") ||
    q.includes("شراء") ||
    q.includes("بيع")
  ) {
    return {
      intent: "search_properties",
      filters: extractPropertyFilters(q),
    };
  }

  // Fallback: general question → use documentation RAG
  return { intent: "general" };
}

// Extract simple filters from free-text Arabic question
function extractPropertyFilters(q) {
  const filters = {};

  // Cities (adjust based on your real data)
  if (q.includes("رام الله")) filters.city = "Ramallah";
  if (q.includes("نابلس")) filters.city = "Nablus";
  if (q.includes("الخليل")) filters.city = "Hebron";
  if (q.includes("غزة")) filters.city = "Gaza";
  if (q.includes("القدس")) filters.city = "Jerusalem";

  // Operation type
  if (
    q.includes("إيجار") ||
    q.includes("ايجار") ||
    q.includes("استأجر") ||
    q.includes("استاجر") ||
    q.includes("استئجار")
  ) {
    filters.operation = "rent";
  }
  if (q.includes("شراء") || q.includes("بيع") || q.includes("تملك") || q.includes("تمليك")) {
    filters.operation = "sale";
  }

  // Budget / price range:
  // 1) Range: "بين 500 و 2000 دولار" / "من 500 الى 2000$"
  const rangeMatch =
    q.match(/(\d+)\s*(?:\$|دولار|usd)?\s*(?:الى|إلى|و|-)\s*(\d+)\s*(?:\$|دولار|usd)?/i) ||
    q.match(/من\s+(\d+)\s*(?:\$|دولار|usd)?\s+(?:الى|إلى)\s+(\d+)\s*(?:\$|دولار|usd)?/i);
  if (rangeMatch) {
    const p1 = parseInt(rangeMatch[1], 10);
    const p2 = parseInt(rangeMatch[2], 10);
    const min = Math.min(p1, p2);
    const max = Math.max(p1, p2);
    filters.minPrice = min;
    filters.maxPrice = max;
  } else {
    // 2) Single upper bound: "تحت 400$" / "أقل من 400 دولار"
    const singleMatch = q.match(/(\d+)\s*(\$|دولار|usd)/i);
    if (singleMatch) {
      filters.budget = parseInt(singleMatch[1], 10);
    }
  }

  // Rooms
  const roomsMatch = q.match(/(\d+)\s*(غرف|غرفة|room|rooms)/);
  if (roomsMatch) {
    filters.rooms = parseInt(roomsMatch[1], 10);
  }

  return filters;
}

// ملاحظة: Ollama لا يدعم Function Calling بنفس طريقة OpenAI
// لكن يمكن إضافة المعلومات في الـ prompt مباشرة


/**
 * POST /api/ai/chat
 * محادثة مع AI باستخدام Ollama (Local LLM)
 */
export const chatWithAI = asyncHandler(async (req, res) => {
  const { question } = req.body;

  if (!question || typeof question !== "string" || question.trim().length === 0) {
    return res.status(400).json({
      success: false,
      message: "يرجى إدخال سؤال صحيح",
    });
  }

  try {
    // قراءة ملفات المعرفة
    const knowledgeContent = loadKnowledgeFiles();

    // ✅ الحصول على معلومات المستخدم للـ Role-Aware AI
    const userId = req.user._id.toString();
    const userRole = req.user.role || "tenant";

    // بناء System Prompt حسب الدور (Role-Aware)
    const roleSpecificPrompt = getUserRolePrompt(userRole, userId);
    
    // بناء System Prompt صارم - RAG حقيقي
    const systemPrompt = `You are an AI assistant for a project called SHAQATI.

STRICT RULES (CANNOT BE VIOLATED):

1. You MUST use ONLY information found literally in the project files provided below.
2. If you do not find the information explicitly in the files, you MUST respond with EXACTLY:
   "This information is not available in SHAQATI project files."
3. You are FORBIDDEN from using any general knowledge outside the files.
4. You are FORBIDDEN from guessing or adding roles, features, or screens not mentioned in the files.
5. You MUST mention the file name where you extracted the information from (e.g., README.md, API_ROUTES.md, DB_SCHEMA.md, FOLDER_MAP.md, SCREENS_AND_FEATURES.md, TROUBLESHOOTING.md, PROJECT_DETAILS.md).
6. If the user asks about something general, you MUST say:
   "According to the project files provided, [mention ONLY what exists in the files]"
7. You are FORBIDDEN from mentioning any role, feature, technology, or screen not explicitly present in the files.
8. When solving problems, use ONLY information from TROUBLESHOOTING.md file.
9. When discussing screens, use ONLY information from SCREENS_AND_FEATURES.md file.
10. You are FORBIDDEN from rephrasing the question.
11. You are FORBIDDEN from repetition.
12. You are FORBIDDEN from general or theoretical explanations.
13. If file names are not mentioned, the response is INVALID.

**Project Information (from ai_knowledge/ files):**
${knowledgeContent}

**Your current role: ${userRole.toUpperCase()}**

**Your task:**
- Answer questions about the project using ONLY the attached information
- Solve problems using TROUBLESHOOTING.md guide
- Explain screens and features using SCREENS_AND_FEATURES.md
- ALWAYS mention the file name where you extracted the information from
- Reject the answer if you do not find the information in the files

**Examples of correct answers:**
- Question: "What are the roles in the system?"
  Correct answer: "According to README.md and PROJECT_DETAILS.md files, the system contains 3 roles only: Admin (System Administrator), Landlord (Property Owner), Tenant (Renter)."

- Question: "What are the screens in the app?"
  Correct answer: "According to SCREENS_AND_FEATURES.md file, the app contains [mention ONLY screens listed in the file]"

- Question: "How do I solve connection problem?"
  Correct answer: "According to TROUBLESHOOTING.md file, [mention the solution from the file]"

- Question: "Is there a role called Network Administrator?"
  Correct answer: "This information is not available in SHAQATI project files."

Any violation of these rules is considered a serious error.`;

    // بناء الرسائل لـ Ollama
    const messages = [
      {
        role: "system",
        content: systemPrompt,
      },
      {
        role: "user",
        content: question,
      },
    ];

    // ✅ Log للـ debugging (في development فقط)
    const provider = getAIProvider();
    if (process.env.NODE_ENV === "development") {
      console.log(`📤 إرسال طلب إلى ${provider.type.toUpperCase()}...`);
      console.log("📝 Messages count:", messages.length);
      console.log("📚 Knowledge size:", knowledgeContent.length, "characters");
      console.log("🤖 Model:", provider.model);
    }

    // إرسال الطلب إلى AI Provider (OpenAI)
    // ✅ temperature منخفض جداً (0.1) لضمان الالتزام الصارم بالقواعد
    const finalResponse = await chatWithAIProvider(messages, {
      temperature: 0.1, // Very low to ensure strict adherence to rules
      max_tokens: 2000,
    });

    // ✅ Post-Validation: التحقق من أن الجواب يذكر اسم ملف
    const validFiles = [
      "README.md",
      "API_ROUTES.md",
      "DB_SCHEMA.md",
      "FOLDER_MAP.md",
      "SCREENS_AND_FEATURES.md",
      "TROUBLESHOOTING.md",
      "PROJECT_DETAILS.md",
    ];

    const mentionsFile = validFiles.some((file) => 
      finalResponse.includes(file)
    );

    // إذا لم يذكر اسم ملف، نعيد رسالة الرفض
    if (!mentionsFile && finalResponse.trim().length > 0) {
      console.warn("⚠️  Response does not mention a file name. Rejecting response.");
      return res.json({
        success: true,
        response: "This information is not available in SHAQATI project files.",
        model: provider.model,
        provider: provider.type,
      });
    }

    res.json({
      success: true,
      response: finalResponse,
      model: provider.model,
      provider: provider.type,
    });
  } catch (error) {
    const provider = getAIProvider();
    console.error(`❌ ${provider.type.toUpperCase()} API Error:`, error);
    console.error("❌ Error Details:", {
      message: error.message,
      code: error.code,
    });

    // معالجة الأخطاء مع رسائل واضحة
    let errorMessage = `حدث خطأ أثناء الاتصال بـ ${provider.type.toUpperCase()}`;
    let statusCode = 500;
    let helpMessage = "";

    // OpenAI specific errors
    if (error.message?.includes("API_KEY") || error.message?.includes("OPENAI_API_KEY")) {
      errorMessage = "❌ مفتاح OpenAI API غير موجود";
      statusCode = 503;
      helpMessage = `🔧 خطوات الحل:

1️⃣ اذهب إلى: https://platform.openai.com/api-keys
2️⃣ أنشئ API Key جديد
3️⃣ أضف المفتاح في ملف backend/.env:
   OPENAI_API_KEY=sk-your-api-key-here
4️⃣ أعد تشغيل السيرفر`.trim();
    } else if (error.message?.includes("quota") || error.message?.includes("limit") || error.message?.includes("429")) {
      errorMessage = "⏱️ تم تجاوز الحد المسموح";
      statusCode = 429;
      helpMessage = `تم تجاوز حد الطلبات لـ OpenAI.

🔧 الحل:
انتظر قليلاً ثم جرب مرة أخرى أو راجع حسابك في OpenAI`;
    } else if (error.message?.includes("invalid") || error.message?.includes("Invalid") || error.message?.includes("401") || error.message?.includes("403")) {
      errorMessage = "❌ مفتاح OpenAI API غير صحيح";
      statusCode = 401;
      helpMessage = `يرجى التحقق من أن مفتاح API صحيح ومفعل في ملف .env`;
    } else if (error.message?.includes("timeout")) {
      errorMessage = "⏱️ انتهت مهلة الاتصال";
      statusCode = 504;
      helpMessage = "الطلب أخذ وقتاً طويلاً. يرجى المحاولة مرة أخرى.";
    } else {
      errorMessage = `خطأ: ${error.message || 'خطأ غير معروف'}`;
      helpMessage = `يرجى التحقق من إعدادات ${provider.type.toUpperCase()} API`;
    }

    res.status(statusCode).json({
      success: false,
      message: errorMessage,
      help: helpMessage || undefined,
      provider: provider.type,
      code: error.code || 'unknown_error',
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
});

/**
 * POST /api/ai/assistant
 * Unified smart assistant with intent detection (properties, contracts, payments, map, RAG)
 * Body: { question: string }
 */
export const aiAssistant = asyncHandler(async (req, res) => {
  const { question } = req.body;
  const userId = req.user?._id?.toString();

  if (!question || typeof question !== "string" || question.trim().length === 0) {
    return res.status(400).json({
      success: false,
      message: "يرجى إدخال سؤال نصي صحيح",
    });
  }

  const { intent, filters = {} } = parseIntent(question);

  // 1) Property search (with or without map)
  if (intent === "search_properties_on_map" || intent === "search_properties") {
    const query = { status: "available" };

    // Price filter: support ranges and single upper bound
    if (filters.minPrice || filters.maxPrice) {
      query.price = {};
      if (filters.minPrice) {
        query.price.$gte = filters.minPrice;
      }
      if (filters.maxPrice) {
        query.price.$lte = filters.maxPrice;
      }
    } else if (filters.budget) {
      query.price = { $lte: filters.budget };
    }
    if (filters.city) {
      query.city = filters.city;
    }
    if (filters.rooms) {
      query.bedrooms = { $gte: filters.rooms };
    }
    if (filters.type) {
      query.type = filters.type;
    }
    if (filters.operation) {
      query.operation = filters.operation;
    }

    const properties = await Property.find(query).limit(30).lean();

    // Map markers from GeoJSON location.coordinates [lng, lat]
    const markers = properties
      .filter(
        (p) =>
          p.location &&
          Array.isArray(p.location.coordinates) &&
          p.location.coordinates.length === 2
      )
      .map((p) => ({
        id: p._id,
        title: p.title || "Property",
        lat: p.location.coordinates[1],
        lng: p.location.coordinates[0],
        price: p.price,
        city: p.city,
      }));

    const center =
      markers.length > 0
        ? { lat: markers[0].lat, lng: markers[0].lng }
        : null;

    const priceText =
      filters.minPrice && filters.maxPrice
        ? ` بين ${filters.minPrice}$ و ${filters.maxPrice}$`
        : filters.budget
        ? ` بميزانية حتى ${filters.budget}$`
        : "";

    const answer =
      properties.length > 0
        ? `وجدت ${properties.length} عقار/عقارات تطابق طلبك تقريباً${
            filters.city ? ` في ${filters.city}` : ""
          }${priceText}. يمكنك استعراضها في القائمة من شاشة الذكاء الاصطناعي، وسيتم عرضها أيضاً على الخريطة إن توفرت إحداثيات.`
        : "حالياً لا يوجد عقارات تطابق طلبك. جرّب تعديل المدينة أو الميزانية أو عدد الغرف.";

    return res.json({
      success: true,
      intent,
      answer,
      properties,
      map: center
        ? {
            center,
            markers,
          }
        : null,
      filters,
    });
  }

  // 2) Contracts expiring soon
  if (intent === "contracts_expiring_soon") {
    const now = new Date();
    const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    const contracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
      endDate: { $gte: now, $lte: in30Days },
    })
      .populate("propertyId", "title city")
      .lean();

    const answer =
      contracts.length > 0
        ? `لديك ${contracts.length} عقد ينتهي خلال 30 يوم القادمة. تأكد من مراجعة التجديد أو الإخلاء في الوقت المناسب.`
        : "لا يوجد حالياً عقود تنتهي خلال الشهر القادم لحسابك.";

    return res.json({
      success: true,
      intent,
      answer,
      contracts,
    });
  }

  // 3) Late payments (pending / failed with date < now) for user's contracts
  if (intent === "late_payments") {
    const now = new Date();

    const rawPayments = await Payment.find({
      status: { $ne: "paid" },
      date: { $lt: now },
    })
      .populate({
        path: "contractId",
        populate: [
          { path: "tenantId", select: "name" },
          { path: "landlordId", select: "name" },
          { path: "propertyId", select: "title city" },
        ],
      })
      .lean();

    const payments = rawPayments.filter((p) => {
      const c = p.contractId;
      if (!c) return false;
      const tenantId =
        (c.tenantId && c.tenantId._id?.toString()) ||
        (typeof c.tenantId === "string" ? c.tenantId : null);
      const landlordId =
        (c.landlordId && c.landlordId._id?.toString()) ||
        (typeof c.landlordId === "string" ? c.landlordId : null);
      return tenantId === userId || landlordId === userId;
    });

    const answer =
      payments.length > 0
        ? `هناك ${payments.length} دفعة متأخرة مرتبطة بعقودك. يُفضّل متابعتها وتسويتها في أقرب وقت.`
        : "لا يوجد حالياً أي دفعات متأخرة مسجلة على عقودك.";

    return res.json({
      success: true,
      intent,
      answer,
      payments,
    });
  }

  // 4) List all contracts for current user (optionally filtered by status)
  if (intent === "list_contracts") {
    const statusMap = {
      "فعالة": "active",
      "الفعالة": "active",
      "منتهية": "expired",
      "المنتهية": "expired",
      "معلقة": "pending",
      "قيد الموافقة": "pending",
      "جديدة": "pending",
    };

    let statusFilter = null;
    const lowerQ = question.toLowerCase();
    Object.entries(statusMap).forEach(([word, status]) => {
      if (lowerQ.includes(word)) {
        statusFilter = status;
      }
    });

    const query = {
      $or: [{ tenantId: userId }, { landlordId: userId }],
    };
    if (statusFilter) {
      query.status = statusFilter;
    }

    const contracts = await Contract.find(query)
      .populate("propertyId", "title city")
      .populate("tenantId", "name")
      .populate("landlordId", "name")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const answer =
      contracts.length > 0
        ? `تم العثور على ${contracts.length} عقد مرتبط بحسابك${statusFilter ? ` بحالة ${statusFilter}` : ""}. يمكنك فتح أي عقد من شاشة الذكاء الاصطناعي باستخدام معرّف العقد أو الضغط على العنصر في الواجهة.`
        : "لا يوجد عقود مطابقة لطلبك حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      filters: { status: statusFilter || null },
      contracts,
    });
  }

  // 5) List all payments for current user's contracts
  if (intent === "list_payments") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();

    const contractIds = userContracts.map((c) => c._id);

    const payments = await Payment.find({
      contractId: { $in: contractIds },
    })
      .populate({
        path: "contractId",
        populate: [{ path: "propertyId", select: "title city" }],
      })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    const answer =
      payments.length > 0
        ? `تم العثور على ${payments.length} دفعة مرتبطة بعقودك. يمكنك عرض تفاصيل كل دفعة وفتح شاشة العقد المرتبطة بها من واجهة الذكاء الاصطناعي.`
        : "لا يوجد أي دفعات مسجلة لعقودك حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      payments,
    });
  }

  // 6) List maintenance requests for current user (tenant perspective)
  if (intent === "list_maintenance") {
    const requests = await MaintenanceRequest.find({ tenantId: userId })
      .populate("propertyId", "title city")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const answer =
      requests.length > 0
        ? `لديك ${requests.length} طلب/طلبات صيانة. يمكنك فتح أي طلب من شاشة الذكاء الاصطناعي لمتابعة حالته.`
        : "لا يوجد لديك طلبات صيانة مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      maintenanceRequests: requests,
    });
  }

  // 7) List complaints submitted by current user
  if (intent === "list_complaints") {
    const complaints = await Complaint.find({ submittedBy: userId })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const answer =
      complaints.length > 0
        ? `لديك ${complaints.length} شكوى مسجلة. يمكنك مراجعة حالة كل شكوى من شاشة الذكاء الاصطناعي.`
        : "لا يوجد لديك شكاوى مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      complaints,
    });
  }

  // 8) List notifications for current user
  if (intent === "list_notifications") {
    const notifs = await Notification.find({ recipientId: userId })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const unreadCount = notifs.filter((n) => !n.read).length;

    const answer =
      notifs.length > 0
        ? `لديك ${notifs.length} إشعار في النظام، منها ${unreadCount} غير مقروء. يمكنك فتح أي إشعار من شاشة الذكاء الاصطناعي لعرض تفاصيله.`
        : "لا يوجد لديك إشعارات في الوقت الحالي.";

    return res.json({
      success: true,
      intent,
      answer,
      notifications: notifs,
    });
  }

  // 9) List financial operations (expenses, deposits, invoices) related to user's contracts/properties
  if (intent === "list_financial") {
    // Get user's contracts to derive related properties/contracts
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id propertyId")
      .lean();

    const contractIds = userContracts.map((c) => c._id);
    const propertyIds = userContracts
      .map((c) => c.propertyId)
      .filter(Boolean);

    const [expenses, deposits, invoices] = await Promise.all([
      Expense.find({
        $or: [
          { contractId: { $in: contractIds } },
          { propertyId: { $in: propertyIds } },
        ],
      })
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .catch(() => []),
      Deposit.find({ contractId: { $in: contractIds } })
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .catch(() => []),
      Invoice.find({ contractId: { $in: contractIds } })
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .catch(() => []),
    ]);

    const answer = `ملخص العمليات المالية المرتبطة بك:
- عدد المصاريف: ${expenses.length}
- عدد الودائع: ${deposits.length}
- عدد الفواتير: ${invoices.length}

يمكنك فتح أي عنصر من شاشة الذكاء الاصطناعي للانتقال إلى شاشة التفاصيل.`;

    return res.json({
      success: true,
      intent,
      answer,
      expenses,
      deposits,
      invoices,
    });
  }

  // 10) Dashboard-like summary (uses DB snapshot)
  if (intent === "dashboard_summary") {
    const snapshot = await _buildDatabaseSnapshot(userId);

    const answer = `إليك ملخص سريع عن النظام وحسابك:

${snapshot.globalSummary}

${snapshot.userSummary}

يمكنك أن تطلب تفاصيل إضافية عن أي جزء (مثلاً: عقودك، دفعاتك، أو العقارات المتاحة).`;

    return res.json({
      success: true,
      intent,
      answer,
      snapshot,
    });
  }

  // 11) General questions → use project documentation (RAG) + live database snapshot (Arabic)
  const knowledgeContent = loadKnowledgeFiles();
  const userRole = req.user?.role || "tenant";
  const roleSpecificPrompt = getUserRolePrompt(userRole, userId);
  const dbSnapshot = await _buildDatabaseSnapshot(userId);

  const systemPrompt = `${roleSpecificPrompt}

ملخص مباشر من قاعدة البيانات (حتى لحظة هذا الطلب):
${dbSnapshot.globalSummary}

${dbSnapshot.userSummary}

المعلومات التالية مأخوذة من ملفات توثيق مشروع SHAQATI (ai_knowledge):
${knowledgeContent}

أجب عن أسئلة المستخدم باللغة العربية اعتماداً على هذه البيانات وملفات التوثيق. إذا لم تجد المعلومة في الملفات أو في الملخص، وضّح ذلك للمستخدم بصراحة.`;

  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: question },
  ];

  const provider = getAIProvider();
  const aiResponse = await chatWithAIProvider(messages, {
    temperature: 0.2,
    max_tokens: 1500,
  });

  return res.json({
    success: true,
    intent,
    answer: aiResponse,
    provider: provider.type,
    model: provider.model,
  });
});

/**
 * POST /api/ai/recommend
 * Chatbot endpoint with database integration
 * Body: { question: string, filters?: { budget?, city?, rooms?, type?, operation? } }
 */
export const aiRecommend = asyncHandler(async (req, res) => {
  try {
    const { question, filters = {} } = req.body;
    const userId = req.user._id.toString();
    const userRole = req.user.role || "tenant";

    if (!question) {
      return res.status(400).json({
        success: false,
        message: "Question is required",
      });
    }

    // ✅ 1. Query Database based on filters and user preferences
    const query = { status: "available" };

    // Apply price filters (range or single upper bound)
    if (filters.minPrice || filters.maxPrice) {
      query.price = {};
      if (filters.minPrice) {
        query.price.$gte = filters.minPrice;
      }
      if (filters.maxPrice) {
        query.price.$lte = filters.maxPrice;
      }
    } else if (filters.budget) {
      query.price = { $lte: filters.budget };
    }
    if (filters.city) {
      query.city = filters.city;
    }
    if (filters.rooms) {
      query.bedrooms = { $gte: filters.rooms };
    }
    if (filters.type) {
      query.type = filters.type;
    }
    if (filters.operation) {
      query.operation = filters.operation;
    }

    // Get user profile for smart recommendations
    const userProfile = await UserProfile.findOne({ userId });
    const userBehavior = await UserBehavior.findOne({ userId });

    // Enhance query with user preferences if available
    if (userProfile) {
      if (userProfile.budgetRange?.max && !query.price) {
        query.price = { $lte: userProfile.budgetRange.max };
      }
      if (userProfile.preferredLocations?.length > 0 && !query.city) {
        const cities = userProfile.preferredLocations.map((l) => l.city);
        query.city = { $in: cities };
      }
      if (userProfile.preferredPropertyTypes?.length > 0 && !query.type) {
        const types = userProfile.preferredPropertyTypes.map((t) => t.type);
        query.type = { $in: types };
      }
    }

    // ✅ 2. Fetch properties from database
    let properties = await Property.find(query)
      .populate("ownerId", "name email")
      .limit(20)
      .lean();

    // ✅ 2.5. Get user's contracts, payments, maintenance requests for context
    const userContracts = await Contract.find({ 
      $or: [{ tenantId: userId }, { landlordId: userId }] 
    })
      .populate("propertyId", "title city price")
      .populate("tenantId", "name")
      .populate("landlordId", "name")
      .limit(5)
      .lean();

    const userPayments = await Payment.find({ 
      contractId: { $in: userContracts.map(c => c._id) } 
    })
      .populate("contractId")
      .sort({ createdAt: -1 })
      .limit(5)
      .lean();

    const userMaintenance = await MaintenanceRequest.find({ tenantId: userId })
      .populate("propertyId", "title city")
      .sort({ createdAt: -1 })
      .limit(5)
      .lean();

    const userComplaints = await Complaint.find({ submittedBy: userId })
      .sort({ createdAt: -1 })
      .limit(5)
      .lean();

    // ✅ 3. If no properties found, return helpful message
    if (properties.length === 0) {
      return res.json({
        success: true,
        response: `حالياً لا يوجد عقارات تطابق معاييرك. جرّب:
• تغيير السعر (الميزانية الحالية: ${filters.budget ? `\$${filters.budget}` : 'غير محدد'})
• تغيير المدينة (${filters.city || 'غير محدد'})
• تقليل عدد الغرف المطلوبة
• أو انتظر قليلاً لتحديث التوصيات 😊`,
        properties: [],
        suggestions: {
          adjustPrice: true,
          adjustCity: true,
          adjustRooms: true,
        },
      });
    }

    // ✅ 4. Prepare properties data for AI
    const propertiesData = properties.map((p) => ({
      id: p._id.toString(),
      title: p.title || "Property",
      city: p.city || "Unknown",
      price: p.price || 0,
      type: p.type || "Unknown",
      bedrooms: p.bedrooms || 0,
      bathrooms: p.bathrooms || 0,
      area: p.area || 0,
      operation: p.operation || "rent",
      address: p.address || "",
    }));

    // ✅ 5. Load knowledge files
    const knowledgeContent = loadKnowledgeFiles();

    // ✅ 6. Prepare user data context (simplified for faster processing)
    const userDataContext = {
      contractsCount: userContracts.length,
      contracts: userContracts.slice(0, 3).map(c => ({
        property: c.propertyId?.title || 'Unknown',
        city: c.propertyId?.city || 'Unknown',
        status: c.status,
        rentAmount: c.rentAmount,
      })),
      paymentsCount: userPayments.length,
      payments: userPayments.slice(0, 3).map(p => ({
        amount: p.amount,
        status: p.status,
      })),
      maintenanceCount: userMaintenance.length,
      maintenance: userMaintenance.slice(0, 3).map(m => ({
        property: m.propertyId?.title || 'Unknown',
        status: m.status,
      })),
      complaintsCount: userComplaints.length,
      complaints: userComplaints.slice(0, 3).map(c => ({
        category: c.category,
        status: c.status,
      })),
    };

    // ✅ 7. Build concise prompt for faster processing
    const systemPrompt = `You are SHAQATI Smart System Assistant. SHAQATI is a real-estate rental and property management platform.

**Your Personality:**
- Be friendly, warm, and human-like
- Respond naturally to greetings (مرحبا, كيفك, etc.)
- Be conversational and engaging
- Use emojis appropriately
- Be helpful and proactive

**Your Role:**
- Help users find suitable properties
- Answer questions about contracts, payments, maintenance, complaints
- Provide recommendations based on ACTUAL DATA ONLY
- Answer in Arabic
- Be specific and accurate

**Available Properties (${propertiesData.length}):**
${propertiesData.map(p => `${p.title} - ${p.city} - \$${p.price} - ${p.type} - ${p.bedrooms} beds`).join('\n')}

**User Data:**
- Contracts: ${userDataContext.contractsCount} (${userDataContext.contracts.map(c => `${c.property} (${c.status})`).join(', ')})
- Payments: ${userDataContext.paymentsCount} (${userDataContext.payments.map(p => `\$${p.amount} (${p.status})`).join(', ')})
- Maintenance: ${userDataContext.maintenanceCount} (${userDataContext.maintenance.map(m => `${m.property} (${m.status})`).join(', ')})
- Complaints: ${userDataContext.complaintsCount} (${userDataContext.complaints.map(c => `${c.category} (${c.status})`).join(', ')})

**User Question:** ${question}

**CRITICAL RULES:**
1. Use ONLY the data provided above - DO NOT invent or guess
2. If data is not available, say "لا توجد معلومات متاحة حالياً" (No information available)
3. Be specific: mention exact property titles, cities, prices from the data
4. Answer in Arabic
5. Keep responses concise (max 150 words)
6. If user asks about properties, list them from the data above`;

    // ✅ 8. Call AI with ALL database data
    const messages = [
      {
        role: "system",
        content: systemPrompt,
      },
      {
        role: "user",
        content: question,
      },
    ];

    let aiResponse;
    try {
      aiResponse = await chatWithAIProvider(messages, {
        temperature: 0.3,
        max_tokens: 800, // Reduced for faster responses
      });
    } catch (error) {
      console.error("❌ AI Error:", error);
      // Smart fallback based on question type
      aiResponse = _generateSmartFallback(question, propertiesData, userDataContext);
    }

    // ✅ 9. Validate and clean response
    let finalResponse = aiResponse;
    if (!finalResponse || finalResponse.trim().length === 0) {
      finalResponse = _generateSmartFallback(question, propertiesData, userDataContext);
    }

    // ✅ 10. Return response with all data
    res.json({
      success: true,
      response: finalResponse,
      data: {
        properties: propertiesData.slice(0, 5), // Top 5 for display
        contracts: userDataContext.contracts,
        payments: userDataContext.payments,
        maintenance: userDataContext.maintenance,
        complaints: userDataContext.complaints,
      },
      summary: {
        totalProperties: properties.length,
        totalContracts: userDataContext.contractsCount,
        totalPayments: userDataContext.paymentsCount,
        totalMaintenance: userDataContext.maintenanceCount,
        totalComplaints: userDataContext.complaintsCount,
      },
      filters: filters,
    });
  } catch (error) {
    console.error("❌ AI Recommend Error:", error);
    res.status(500).json({
      success: false,
      message: "Error processing recommendation",
      error: error.message,
    });
  }
});

/**
 * GET /api/ai/health
 * فحص حالة AI Service (OpenAI)
 */
export const checkAIHealth = asyncHandler(async (req, res) => {
  const knowledgeContent = loadKnowledgeFiles();
  const hasKnowledge = knowledgeContent.length > 0;
  
  // فحص حالة OpenAI API
  const provider = getAIProvider();
  const healthStatus = await checkAIProviderHealth();

  res.json({
    success: true,
    health: {
      available: healthStatus.available || false,
      models: healthStatus.models || [],
      targetModel: healthStatus.model || provider.model,
      hasTargetModel: healthStatus.hasTargetModel !== undefined ? healthStatus.hasTargetModel : true,
      knowledgeFilesLoaded: hasKnowledge,
      knowledgeSize: knowledgeContent.length,
      provider: healthStatus.provider || "OpenAI",
      status: healthStatus.status || (healthStatus.available ? "ready" : "not_configured"),
      error: healthStatus.error || undefined,
    },
    message: healthStatus.available
      ? hasKnowledge 
        ? `AI Service جاهز للاستخدام (${healthStatus.provider || "OpenAI"}) مع ملفات المعرفة`
        : `AI Service جاهز (${healthStatus.provider || "OpenAI"}) لكن بدون ملفات معرفة`
      : healthStatus.error || `يرجى إعداد ${healthStatus.provider || "OpenAI"} API. راجع ملف التوثيق`,
  });
});

// Helper function to generate smart fallback responses
function _generateSmartFallback(question, propertiesData, userDataContext) {
  const normalizedQuestion = question.toLowerCase();
  
  // Property-related questions
  if (normalizedQuestion.includes('عقار') || normalizedQuestion.includes('property')) {
    if (propertiesData.length > 0) {
      const top3 = propertiesData.slice(0, 3);
      return `لدينا ${propertiesData.length} عقار متاح:\n\n${top3.map((p, i) => 
        `${i + 1}. ${p.title} - ${p.city}\n   السعر: \$${p.price} | النوع: ${p.type} | الغرف: ${p.bedrooms}`
      ).join('\n\n')}\n\nاستخدم الأزرار أدناه لعرض التفاصيل الكاملة.`;
    }
    return 'حالياً لا يوجد عقارات متاحة. جرّب تغيير الفلاتر أو انتظر قليلاً.';
  }
  
  // Contracts
  if (normalizedQuestion.includes('عقد') || normalizedQuestion.includes('contract')) {
    if (userDataContext.contractsCount > 0) {
      return `لديك ${userDataContext.contractsCount} عقد:\n${userDataContext.contracts.map(c => 
        `• ${c.property} (${c.city}) - \$${c.rentAmount} - ${c.status}`
      ).join('\n')}`;
    }
    return 'لا توجد عقود متاحة حالياً.';
  }
  
  // Payments
  if (normalizedQuestion.includes('دفعة') || normalizedQuestion.includes('payment')) {
    if (userDataContext.paymentsCount > 0) {
      return `لديك ${userDataContext.paymentsCount} دفعة:\n${userDataContext.payments.map(p => 
        `• \$${p.amount} - ${p.status}`
      ).join('\n')}`;
    }
    return 'لا توجد دفعات متاحة حالياً.';
  }
  
  // Maintenance
  if (normalizedQuestion.includes('صيانة') || normalizedQuestion.includes('maintenance')) {
    if (userDataContext.maintenanceCount > 0) {
      return `لديك ${userDataContext.maintenanceCount} طلب صيانة:\n${userDataContext.maintenance.map(m => 
        `• ${m.property} - ${m.status}`
      ).join('\n')}`;
    }
    return 'لا توجد طلبات صيانة حالياً.';
  }
  
  // Default
  return 'كيف يمكنني مساعدتك؟ يمكنك:\n• البحث عن العقارات\n• متابعة عقودك ودفعاتك\n• عرض الإحصائيات\n• استخدام الخريطة';
}

// Helper: build a compact snapshot from MongoDB so AI "knows" live data
async function _buildDatabaseSnapshot(userId) {
  try {
    const [
      totalUsers,
      totalProperties,
      totalContracts,
      totalPayments,
      totalBuildings,
      totalUnits,
      totalExpenses,
      totalDeposits,
      totalInvoices,
      totalMaintenance,
      totalComplaints,
      totalNotifications,
      totalReviews,
    ] = await Promise.all([
      User.countDocuments().catch(() => 0),
      Property.countDocuments().catch(() => 0),
      Contract.countDocuments().catch(() => 0),
      Payment.countDocuments().catch(() => 0),
      Building.countDocuments().catch(() => 0),
      Unit.countDocuments().catch(() => 0),
      Expense.countDocuments().catch(() => 0),
      Deposit.countDocuments().catch(() => 0),
      Invoice.countDocuments().catch(() => 0),
      MaintenanceRequest.countDocuments().catch(() => 0),
      Complaint.countDocuments().catch(() => 0),
      Notification.countDocuments().catch(() => 0),
      Review.countDocuments().catch(() => 0),
    ]);

    let userSummary = "لم يتم العثور على مستخدم حالي أو لا يوجد بيانات مرتبطة به.\n";

    if (userId) {
      const [
        userContracts,
        userPayments,
        userLatePayments,
        userMaintenance,
        userComplaints,
        userNotifications,
        userChats,
      ] = await Promise.all([
        Contract.find({ $or: [{ tenantId: userId }, { landlordId: userId }] })
          .select("status startDate endDate rentAmount")
          .limit(10)
          .lean()
          .catch(() => []),
        Payment.find({ "contractId": { $exists: true } })
          .populate({
            path: "contractId",
            match: { $or: [{ tenantId: userId }, { landlordId: userId }] },
            select: "_id",
          })
          .limit(20)
          .lean()
          .catch(() => []),
        Payment.find({
          status: { $ne: "paid" },
          date: { $lt: new Date() },
        })
          .populate({
            path: "contractId",
            match: { $or: [{ tenantId: userId }, { landlordId: userId }] },
            select: "_id",
          })
          .limit(20)
          .lean()
          .catch(() => []),
        MaintenanceRequest.find({ tenantId: userId })
          .select("status")
          .limit(10)
          .lean()
          .catch(() => []),
        Complaint.find({ submittedBy: userId })
          .select("status category")
          .limit(10)
          .lean()
          .catch(() => []),
        Notification.find({ recipientId: userId })
          .select("read type")
          .limit(20)
          .lean()
          .catch(() => []),
        Chat.find({
          $or: [{ senderId: userId }, { receiverId: userId }],
        })
          .limit(20)
          .lean()
          .catch(() => []),
      ]);

      const filteredUserPayments = userPayments.filter((p) => p.contractId);
      const filteredLate = userLatePayments.filter((p) => p.contractId);

      const unreadNotifications = userNotifications.filter((n) => !n.read).length;

      userSummary = `
بيانات مرتبطة بالمستخدم الحالي:
- عدد العقود: ${userContracts.length}
- عدد الدفعات الإجمالية: ${filteredUserPayments.length}
- عدد الدفعات المتأخرة: ${filteredLate.length}
- عدد طلبات الصيانة: ${userMaintenance.length}
- عدد الشكاوى: ${userComplaints.length}
- عدد الإشعارات الكلية: ${userNotifications.length} (منها ${unreadNotifications} غير مقروءة)
- عدد الرسائل في المحادثات: ${userChats.length}
`.trim();
    }

    const globalSummary = `
ملخص عام لقاعدة البيانات:
- عدد المستخدمين: ${totalUsers}
- عدد العقارات: ${totalProperties}
- عدد العقود: ${totalContracts}
- عدد الدفعات: ${totalPayments}
- عدد المباني: ${totalBuildings}
- عدد الوحدات: ${totalUnits}
- عدد المصاريف: ${totalExpenses}
- عدد الودائع: ${totalDeposits}
- عدد الفواتير: ${totalInvoices}
- عدد طلبات الصيانة: ${totalMaintenance}
- عدد الشكاوى: ${totalComplaints}
- عدد الإشعارات: ${totalNotifications}
- عدد التقييمات: ${totalReviews}
`.trim();

    return { globalSummary, userSummary };
  } catch (error) {
    console.error("❌ Error building DB snapshot for AI:", error);
    return {
      globalSummary: "تعذر تحميل ملخص قاعدة البيانات بسبب خطأ غير متوقع.",
      userSummary: "",
    };
  }
}
