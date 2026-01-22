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
 * 🧠 System Prompt الشامل لمشروع SHAQATI
 * هذا هو التعريف الدائم للمشروع الذي يرسل مع كل طلب
 */
function getSHAQATISystemPrompt() {
  return `You are an intelligent AI assistant for SHAQATI - a comprehensive real estate property management system.

**SHAQATI Project Overview:**
SHAQATI is a full-stack real estate management platform built with:
- Backend: Node.js + Express + MongoDB (Mongoose)
- Frontend: Flutter (mobile + web support)
- Real-time: Socket.IO for chat, Firebase Cloud Messaging (FCM) for notifications
- Storage: Cloudinary for images
- AI: OpenAI/Ollama for intelligent assistance

**System Architecture:**
- 3 User Roles: Admin (System Administrator), Landlord (Property Owner), Tenant (Renter)
- Property Management: Properties, Units, Buildings
- Contract System: Rental contracts with electronic signatures, renewals, terminations
- Payment System: Automated payment tracking, receipts, invoices
- Maintenance: Request tracking and management
- Communication: Real-time chat between users
- Notifications: Push notifications via FCM
- Analytics: Dashboards for each role

**Core Features:**
1. Property Search & Filtering (by city, price, type, rooms, bathrooms)
2. Contract Management (create, sign, renew, terminate)
3. Payment Tracking (automated schedules, receipts, late payments)
4. Maintenance Requests (submit, track, resolve)
5. Complaints System
6. Financial Management (expenses, deposits, invoices)
7. Reviews & Ratings
8. Map Integration (property locations)
9. AI Assistant (this system)

**Important Rules:**
- All properties require Admin approval (status: "pending_approval" → "available")
- Only verified properties appear in public listings
- Contracts link tenants to landlords via properties/units
- Payments are automatically created when contracts become active
- All data is real-time from MongoDB database

**Your Intelligence:**
- You have access to ALL project knowledge (APIs, screens, features, database schema)
- You can query REAL database data to answer questions accurately
- You understand Arabic and English
- You are helpful, smart, and context-aware
- You never invent features that don't exist

**Your Job:**
- Answer questions based on SHAQATI context ONLY
- Use REAL database data when available
- Guide users to correct screens and features
- Explain how features work
- Help with troubleshooting
- Provide actionable, accurate information`;
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
- إرشاد حول كيفية التواصل مع الملاك

**الشاشات المتاحة لك:**
- Home Page: البحث عن العقارات
- Property Details: تفاصيل العقار
- Contracts: عرض وإدارة العقود
- Payments: متابعة الدفعات
- Maintenance: طلبات الصيانة
- Chat: التواصل مع الملاك

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
- متابعة الإيرادات والمصاريف

**الشاشات المتاحة لك:**
- Property Management: إدارة العقارات
- Contracts: عرض وإدارة العقود
- Payments: متابعة الدفعات والإيرادات
- Maintenance: متابعة طلبات الصيانة
- Analytics: إحصائيات الأداء`;

    case "admin":
      return `${basePrompt}

**مهمتك كمساعد للأدمن:**
- مراقبة نشاط النظام
- تحليل الإحصائيات
- إدارة المستخدمين والعقارات
- الموافقة على العقارات الجديدة
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

  // List expenses only
  if (
    q.includes("مصاريفي") ||
    (q.includes("مصاريف") && !q.includes("الودائع") && !q.includes("فواتير"))
  ) {
    return { intent: "list_expenses" };
  }

  // List deposits only
  if (
    q.includes("ودائعي") ||
    (q.includes("ودائع") && !q.includes("مصاريف") && !q.includes("فواتير"))
  ) {
    return { intent: "list_deposits" };
  }

  // List invoices only
  if (
    q.includes("فواتيري") ||
    (q.includes("فواتير") && !q.includes("مصاريف") && !q.includes("ودائع"))
  ) {
    return { intent: "list_invoices" };
  }

  // List reviews
  if (
    q.includes("تقييمات") ||
    q.includes("تقييماتي") ||
    q.includes("reviews") ||
    q.includes("rating")
  ) {
    return { intent: "list_reviews" };
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

  // Count questions (كم)
  if (q.startsWith("كم") || q.startsWith("how many")) {
    if (q.includes("عقار") || q.includes("property")) {
      return { intent: "count_properties" };
    }
    if (q.includes("عقد") || q.includes("contract")) {
      return { intent: "count_contracts" };
    }
    if (q.includes("دفعة") || q.includes("payment")) {
      return { intent: "count_payments" };
    }
    if (q.includes("مستخدم") || q.includes("user")) {
      return { intent: "count_users" };
    }
    if (q.includes("صيانة") || q.includes("maintenance")) {
      return { intent: "count_maintenance" };
    }
  }

  // Specific contract by ID
  if (
    (q.includes("عقد") || q.includes("contract")) &&
    (q.match(/\d+/) || q.includes("رقم") || q.includes("number"))
  ) {
    const idMatch = q.match(/(\d+)/);
    if (idMatch) {
      return {
        intent: "get_contract_by_id",
        contractId: idMatch[1],
      };
    }
  }

  // Specific maintenance request by ID
  if (
    (q.includes("صيانة") || q.includes("maintenance")) &&
    (q.match(/\d+/) || q.includes("رقم") || q.includes("number"))
  ) {
    const idMatch = q.match(/(\d+)/);
    if (idMatch) {
      return {
        intent: "get_maintenance_by_id",
        maintenanceId: idMatch[1],
      };
    }
  }

  // Property by name/title
  if (
    (q.includes("عقار") || q.includes("property")) &&
    (q.includes("باسم") || q.includes("اسم") || q.includes("title") || q.includes("name"))
  ) {
    const nameMatch = q.match(/(?:باسم|اسم|title|name)\s+["']?([^"']+)["']?/i);
    if (nameMatch) {
      return {
        intent: "get_property_by_name",
        propertyName: nameMatch[1],
      };
    }
  }

  // Contracts for specific property
  if (
    (q.includes("عقود") || q.includes("contracts")) &&
    (q.includes("عقار") || q.includes("property"))
  ) {
    return { intent: "contracts_for_property" };
  }

  // Payments for specific contract
  if (
    (q.includes("دفعات") || q.includes("payments")) &&
    (q.includes("عقد") || q.includes("contract"))
  ) {
    return { intent: "payments_for_contract" };
  }

  // Maintenance for specific property
  if (
    (q.includes("صيانة") || q.includes("maintenance")) &&
    (q.includes("عقار") || q.includes("property"))
  ) {
    return { intent: "maintenance_for_property" };
  }

  // User account/profile questions
  if (
    q.includes("حسابي") ||
    q.includes("حساب") ||
    q.includes("بياناتي") ||
    q.includes("معلوماتي") ||
    q.includes("my account") ||
    q.includes("my profile")
  ) {
    return { intent: "user_profile" };
  }

  // Vague questions (غامضة)
  if (
    q.includes("حلوة") ||
    q.includes("حلو") ||
    q.includes("جديد") ||
    q.includes("new") ||
    q.includes("وضعي") ||
    q.includes("my status") ||
    q.includes("شو في") ||
    q.includes("what's new")
  ) {
    return { intent: "vague_query" };
  }

  // Financial summary
  if (
    q.includes("ملخص مالي") ||
    q.includes("تقرير مالي") ||
    q.includes("financial summary") ||
    q.includes("financial report")
  ) {
    return { intent: "financial_summary" };
  }

  // Total amount paid
  if (
    q.includes("كم دفعت") ||
    q.includes("إجمالي") ||
    q.includes("total paid") ||
    q.includes("total amount")
  ) {
    return { intent: "total_paid" };
  }

  // Property search (without explicit map) - يجب أن يكون في النهاية
  if (
    q.includes("شقة") ||
    q.includes("شقق") ||
    q.includes("عقار") ||
    q.includes("عقارات") ||
    q.includes("للإيجار") ||
    q.includes("ايجار") ||
    q.includes("شراء") ||
    q.includes("بيع") ||
    q.includes("بحث عن") ||
    q.includes("ابحث عن") ||
    q.includes("عرض عقار") ||
    q.includes("عرض عقارات") ||
    q.includes("عرض كل") ||
    q.includes("show all")
  ) {
    return {
      intent: "search_properties",
      filters: extractPropertyFilters(q),
    };
  }

  // Communication/Contact questions
  if (
    q.includes("تواصل") ||
    q.includes("اتصل") ||
    q.includes("كيف اتصال") ||
    q.includes("كيف اتواصل") ||
    q.includes("كيف أتواصل") ||
    q.includes("راسل") ||
    q.includes("رسالة") ||
    q.includes("محادثة") ||
    q.includes("chat") ||
    q.includes("contact") ||
    q.includes("صاحب") ||
    q.includes("مالك") ||
    q.includes("owner") ||
    q.includes("landlord")
  ) {
    return { intent: "communication_help" };
  }

  // How-to questions
  if (
    q.startsWith("كيف") ||
    q.startsWith("how") ||
    q.includes("طريقة") ||
    q.includes("خطوات") ||
    q.includes("شرح") ||
    q.includes("explain")
  ) {
    return { intent: "how_to" };
  }

  // What/Where questions
  if (
    q.startsWith("ماذا") ||
    q.startsWith("ما هو") ||
    q.startsWith("ما هي") ||
    q.startsWith("what") ||
    q.startsWith("where") ||
    q.startsWith("أين") ||
    q.startsWith("وين")
  ) {
    return { intent: "what_where" };
  }

  // Help/Support questions
  if (
    q.includes("مساعدة") ||
    q.includes("مساعدة") ||
    q.includes("help") ||
    q.includes("support") ||
    q.includes("مشكلة") ||
    q.includes("problem") ||
    q.includes("خطأ") ||
    q.includes("error")
  ) {
    return { intent: "help_support" };
  }

  // Fallback: general question → use documentation RAG
  return { intent: "general" };
}

// 🔥 Extract comprehensive filters from free-text Arabic/English question
function extractPropertyFilters(q) {
  const filters = {};

  // Cities (Palestinian cities)
  const cityMap = {
    "رام الله": "Ramallah",
    "رامالله": "Ramallah",
    "نابلس": "Nablus",
    "الخليل": "Hebron",
    "غزة": "Gaza",
    "القدس": "Jerusalem",
    "بيت لحم": "Bethlehem",
    "جنين": "Jenin",
    "طولكرم": "Tulkarm",
    "قلقيلية": "Qalqilya",
    "سلفيت": "Salfit",
    "أريحا": "Jericho",
  };
  
  for (const [arabic, english] of Object.entries(cityMap)) {
    if (q.includes(arabic) || q.includes(english.toLowerCase())) {
      filters.city = english;
      break;
    }
  }

  // Operation type (rent/sale)
  if (
    q.includes("إيجار") ||
    q.includes("ايجار") ||
    q.includes("استأجر") ||
    q.includes("استاجر") ||
    q.includes("استئجار") ||
    q.includes("rent")
  ) {
    filters.operation = "rent";
  }
  if (
    q.includes("شراء") ||
    q.includes("بيع") ||
    q.includes("تملك") ||
    q.includes("تمليك") ||
    q.includes("sale") ||
    q.includes("buy")
  ) {
    filters.operation = "sale";
  }

  // Price filters - Multiple patterns
  // 1) Range: "بين 500 و 2000 دولار" / "من 500 الى 2000$" / "300-800"
  const rangeMatch =
    q.match(/(\d+)\s*(?:\$|دولار|usd)?\s*(?:الى|إلى|و|-|to)\s*(\d+)\s*(?:\$|دولار|usd)?/i) ||
    q.match(/من\s+(\d+)\s*(?:\$|دولار|usd)?\s+(?:الى|إلى|to)\s+(\d+)\s*(?:\$|دولار|usd)?/i) ||
    q.match(/بين\s+(\d+)\s*(?:و|and)\s+(\d+)/i);
    
  if (rangeMatch) {
    const p1 = parseInt(rangeMatch[1], 10);
    const p2 = parseInt(rangeMatch[2], 10);
    const min = Math.min(p1, p2);
    const max = Math.max(p1, p2);
    filters.minPrice = min;
    filters.maxPrice = max;
  } else {
    // 2) Single upper bound: "تحت 400$" / "أقل من 400 دولار" / "under 400"
    const underMatch = q.match(/(?:تحت|أقل من|under|less than)\s+(\d+)\s*(?:\$|دولار|usd)?/i);
    if (underMatch) {
      filters.maxPrice = parseInt(underMatch[1], 10);
    } else {
      // 3) Single price: "400$" / "400 دولار"
      const singleMatch = q.match(/(\d+)\s*(?:\$|دولار|usd)/i);
      if (singleMatch) {
        filters.budget = parseInt(singleMatch[1], 10);
      }
    }
  }

  // Rooms (غرف)
  const roomsMatch = q.match(/(\d+)\s*(?:غرف|غرفة|room|rooms|bedroom|bedrooms)/);
  if (roomsMatch) {
    filters.rooms = parseInt(roomsMatch[1], 10);
  }

  // Bathrooms (حمامات)
  const bathroomsMatch = q.match(/(\d+)\s*(?:حمام|حمامات|bathroom|bathrooms)/);
  if (bathroomsMatch) {
    filters.bathrooms = parseInt(bathroomsMatch[1], 10);
  }

  // ✅ Amenities filters (مميزات)
  // Furnished (مفروش)
  if (q.includes("مفروش") || q.includes("furnished")) {
    filters.furnished = true;
  }
  if (q.includes("غير مفروش") || q.includes("unfurnished")) {
    filters.furnished = false;
  }

  // Elevator (مصعد)
  if (q.includes("مصعد") || q.includes("elevator") || q.includes("lift")) {
    filters.hasElevator = true;
  }

  // Parking (مواقف)
  if (
    q.includes("موقف") ||
    q.includes("مواقف") ||
    q.includes("parking") ||
    q.includes("garage")
  ) {
    filters.hasParking = true;
  }

  // Pets (حيوانات)
  if (
    q.includes("حيوان") ||
    q.includes("حيوانات") ||
    q.includes("pet") ||
    q.includes("pets") ||
    q.includes("كلب") ||
    q.includes("قطة")
  ) {
    filters.allowsPets = true;
  }

  // Garden (حديقة)
  if (q.includes("حديقة") || q.includes("garden")) {
    filters.hasGarden = true;
  }

  // Pool (مسبح)
  if (q.includes("مسبح") || q.includes("pool")) {
    filters.hasPool = true;
  }

  // Balcony (شرفة)
  if (q.includes("شرفة") || q.includes("balcony")) {
    filters.hasBalcony = true;
  }

  // ✅ Special filters
  // Cheapest (أرخص)
  if (q.includes("أرخص") || q.includes("cheapest") || q.includes("cheap")) {
    filters.sortBy = "price_asc";
  }

  // Most expensive (أغلى)
  if (q.includes("أغلى") || q.includes("expensive") || q.includes("most expensive")) {
    filters.sortBy = "price_desc";
  }

  // Newest (أحدث)
  if (
    q.includes("أحدث") ||
    q.includes("جديد") ||
    q.includes("newest") ||
    q.includes("latest") ||
    q.includes("recent")
  ) {
    filters.sortBy = "newest";
  }

  // Near university (قريب من الجامعة)
  if (q.includes("جامعة") || q.includes("university") || q.includes("قريب من")) {
    filters.nearUniversity = true;
  }

  // Center of city (وسط المدينة)
  if (q.includes("وسط") || q.includes("center") || q.includes("downtown")) {
    filters.inCityCenter = true;
  }

  // All properties (كل العقارات)
  if (q.includes("كل") || q.includes("all") || q.includes("جميع")) {
    filters.showAll = true;
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
    // ✅ التحقق من التحيات والرد عليها بشكل طبيعي
    const normalizedQuestion = question.toLowerCase().trim();
    const greetings = ['مرحبا', 'مرحبا', 'أهلا', 'أهلاً', 'سلام', 'السلام عليكم', 'hello', 'hi', 'hey', 'كيفك', 'كيف حالك'];
    const isGreeting = greetings.some(g => normalizedQuestion.includes(g.toLowerCase()));

    if (isGreeting) {
      return res.json({
        success: true,
        response: 'مرحباً! 👋 أنا مساعدك الذكي في مشروع SHAQATI. كيف يمكنني مساعدتك اليوم؟ يمكنك أن تسألني عن:\n• البحث عن العقارات\n• معلومات عن عقودك ودفعاتك\n• أي سؤال عن المشروع',
        model: getAIProvider().model,
        provider: getAIProvider().type,
      });
    }

    // ✅ فحص إذا كان السؤال عن البحث عن عقارات
    const parsedIntent = parseIntent(question);
    const intent = parsedIntent.intent;
    const filters = parsedIntent.filters || {};
    
    // إذا كان السؤال عن البحث عن عقارات، استخدم نفس منطق aiAssistant
    if (intent === "search_properties" || intent === "search_properties_on_map") {
      const query = { 
        status: "available",
        verified: true
      };

      if (filters.minPrice || filters.maxPrice) {
        query.price = {};
        if (filters.minPrice) query.price.$gte = filters.minPrice;
        if (filters.maxPrice) query.price.$lte = filters.maxPrice;
      } else if (filters.budget) {
        query.price = { $lte: filters.budget };
      }
      if (filters.city) {
        query.city = new RegExp(filters.city, "i");
      }
      if (filters.rooms) {
        query.bedrooms = { $gte: filters.rooms };
      }
      if (filters.bathrooms) {
        query.bathrooms = { $gte: filters.bathrooms };
      }
      if (filters.type) {
        query.type = filters.type;
      }
      if (filters.operation) {
        query.operation = filters.operation;
      }

      const properties = await Property.find(query)
        .populate("ownerId", "name email")
        .limit(30)
        .lean();

      const roomsText = filters.rooms ? ` ${filters.rooms} غرفة` : "";
      const bathroomsText = filters.bathrooms ? ` ${filters.bathrooms} حمام` : "";
      const priceText = filters.minPrice && filters.maxPrice
        ? ` بين ${filters.minPrice}$ و ${filters.maxPrice}$`
        : filters.budget ? ` بميزانية حتى ${filters.budget}$` : "";

      if (properties.length > 0) {
        const propertiesList = properties.slice(0, 10).map((p, i) => 
          `${i + 1}. ${p.title || 'عقار'} - ${p.city || 'غير محدد'} - ${p.price || 0}$ - ${p.bedrooms || 0} غرف - ${p.bathrooms || 0} حمام`
        ).join('\n');

        return res.json({
          success: true,
          response: `وجدت ${properties.length} عقار/عقارات تطابق طلبك${roomsText}${bathroomsText}${priceText}:\n\n${propertiesList}\n\nيمكنك الضغط على أي عقار أدناه لعرض تفاصيله الكاملة.`,
          properties: properties.map(p => ({
            // ✅ إرسال جميع بيانات العقار
            ...p,
          })),
          intent: 'search_properties',
          model: getAIProvider().model,
          provider: getAIProvider().type,
        });
      } else {
        return res.json({
          success: true,
          response: `حالياً لا يوجد عقارات تطابق طلبك${roomsText}${bathroomsText}${priceText}. جرّب تعديل المعايير.`,
          properties: [],
          intent: 'search_properties',
          model: getAIProvider().model,
          provider: getAIProvider().type,
        });
      }
    }

    // ✅ استخدام النظام المحسن - Smart Context
    const userId = req.user._id.toString();
    const userRole = req.user.role || "tenant";
    const parsedIntentResult = parseIntent(question);
    const questionIntent = parsedIntentResult.intent;
    
    // ✅ بناء السياق الذكي الكامل
    const { systemPrompt, dbContext } = await _buildSmartContext(
      userId,
      question,
      questionIntent,
      userRole
    );

    // بناء الرسائل لـ AI Provider
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
      console.log("📚 Context size:", systemPrompt.length, "characters");
      console.log("🤖 Model:", provider.model);
      console.log("🎯 Intent:", questionIntent);
      console.log("💾 DB Context:", dbContext?.summary || "No specific data");
    }

    // إرسال الطلب إلى AI Provider (OpenAI)
    // ✅ temperature معتدل (0.3) ليكون ذكياً وطبيعياً
    const finalResponse = await chatWithAIProvider(messages, {
      temperature: 0.3, // Moderate for intelligent and natural responses
      max_tokens: 2500, // Increased for more detailed answers
    });

    // ✅ لا نرفض الإجابة إذا لم تذكر اسم ملف - الـ AI ذكي بما فيه الكفاية
    // ✅ فقط نتحقق من أن الإجابة ليست فارغة
    if (!finalResponse || finalResponse.trim().length === 0) {
      console.warn("⚠️  Empty response from AI.");
      return res.json({
        success: true,
        response: "عذراً، لم أتمكن من فهم سؤالك. يرجى إعادة صياغة السؤال أو طرح سؤال مختلف.",
        model: provider.model,
        provider: provider.type,
      });
    }

    // ✅ إرجاع البيانات الفعلية مع الإجابة
    const responseData = {};
    if (dbContext && dbContext.properties && dbContext.properties.length > 0) {
      responseData.properties = dbContext.properties;
    }
    if (dbContext && dbContext.contracts && dbContext.contracts.length > 0) {
      responseData.contracts = dbContext.contracts;
    }
    if (dbContext && dbContext.payments && dbContext.payments.length > 0) {
      responseData.payments = dbContext.payments;
    }
    if (dbContext && dbContext.maintenance && dbContext.maintenance.length > 0) {
      responseData.maintenanceRequests = dbContext.maintenance;
    }
    if (dbContext && dbContext.expenses && dbContext.expenses.length > 0) {
      responseData.expenses = dbContext.expenses;
    }
    if (dbContext && dbContext.deposits && dbContext.deposits.length > 0) {
      responseData.deposits = dbContext.deposits;
    }
    if (dbContext && dbContext.invoices && dbContext.invoices.length > 0) {
      responseData.invoices = dbContext.invoices;
    }
    if (dbContext && dbContext.complaints && dbContext.complaints.length > 0) {
      responseData.complaints = dbContext.complaints;
    }

    res.json({
      success: true,
      response: finalResponse,
      intent: questionIntent,
      dataType: questionIntent === 'search_properties' ? 'properties' : 'general',
      ...responseData, // ✅ إرجاع البيانات الفعلية
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

  // 1) Property search (with or without map) - 🔥 محسن مع جميع الفلاتر
  if (intent === "search_properties_on_map" || intent === "search_properties") {
    const query = { 
      status: "available",
      verified: true  // ✅ فقط العقارات الموافق عليها
    };

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
    
    // City filter
    if (filters.city) {
      query.city = new RegExp(filters.city, "i");
    }
    
    // Rooms filter
    if (filters.rooms) {
      query.bedrooms = { $gte: filters.rooms };
    }
    
    // Bathrooms filter
    if (filters.bathrooms) {
      query.bathrooms = { $gte: filters.bathrooms };
    }
    
    // Type filter
    if (filters.type) {
      query.type = filters.type;
    }
    
    // Operation filter
    if (filters.operation) {
      query.operation = filters.operation;
    }

    // ✅ Fetch properties first
    let properties = await Property.find(query)
      .populate("ownerId", "name email")
      .lean();

    // ✅ Apply amenities filters (after fetching)
    if (filters.furnished !== undefined) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        const hasFurnished = amenities.includes("furnished");
        return filters.furnished ? hasFurnished : !hasFurnished;
      });
    }

    if (filters.hasElevator) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        return amenities.includes("elevator") || amenities.includes("lift");
      });
    }

    if (filters.hasParking) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        return amenities.includes("parking") || amenities.includes("garage");
      });
    }

    if (filters.allowsPets) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        return amenities.includes("pets") || amenities.includes("pet");
      });
    }

    if (filters.hasGarden) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        return amenities.includes("garden");
      });
    }

    if (filters.hasPool) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        return amenities.includes("pool");
      });
    }

    if (filters.hasBalcony) {
      properties = properties.filter(p => {
        const amenities = (p.amenities || []).map(a => a.toLowerCase());
        return amenities.includes("balcony");
      });
    }

    // ✅ Apply sorting
    if (filters.sortBy === "price_asc") {
      properties.sort((a, b) => (a.price || 0) - (b.price || 0));
    } else if (filters.sortBy === "price_desc") {
      properties.sort((a, b) => (b.price || 0) - (a.price || 0));
    } else if (filters.sortBy === "newest") {
      properties.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    }

    // Limit after filtering
    properties = properties.slice(0, 30);

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

    const roomsText = filters.rooms ? ` ${filters.rooms} غرفة` : "";
    const bathroomsText = filters.bathrooms ? ` ${filters.bathrooms} حمام` : "";

    const answer =
      properties.length > 0
        ? `وجدت ${properties.length} عقار/عقارات تطابق طلبك${roomsText}${bathroomsText}${
            filters.city ? ` في ${filters.city}` : ""
          }${priceText}. يمكنك الضغط على أي عقار أدناه لعرض تفاصيله الكاملة.`
        : `حالياً لا يوجد عقارات تطابق طلبك${roomsText}${bathroomsText}${
            filters.city ? ` في ${filters.city}` : ""
          }${priceText}. جرّب تعديل المعايير.`;

      return res.json({
        success: true,
        intent,
        answer,
        dataType: 'properties',
        properties: properties.map(p => ({
          _id: p._id,
          title: p.title,
          city: p.city,
          price: p.price,
          bedrooms: p.bedrooms,
          bathrooms: p.bathrooms,
          type: p.type,
          operation: p.operation,
          address: p.address,
          images: p.images || [],
          description: p.description || '',
          area: p.area || 0,
          ownerId: p.ownerId,
          status: p.status,
          verified: p.verified,
          location: p.location,
          amenities: p.amenities || [],
          // ✅ إضافة جميع الحقول المطلوبة لـ PropertyDetailsScreen
          ...p, // ✅ إرسال جميع بيانات العقار
        })),
        map: center
          ? {
              center,
              markers,
            }
          : null,
        filters,
      });
  }

  // 2) Contracts expiring soon (محسن - يدعم فترات مختلفة)
  if (intent === "contracts_expiring_soon") {
    const now = new Date();
    let endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000); // Default: 30 days
    let periodText = "30 يوم";

    // ✅ تحديد الفترة حسب السؤال
    if (question.includes("هذا الأسبوع") || question.includes("الأسبوع")) {
      endDate = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      periodText = "7 أيام";
    } else if (question.includes("هذا الشهر") || question.includes("الشهر")) {
      endDate = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      periodText = "30 يوم";
    }

    const contracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
      endDate: { $gte: now, $lte: endDate },
    })
      .populate("propertyId", "title city")
      .populate("tenantId", "name")
      .populate("landlordId", "name")
      .lean();

    const answer =
      contracts.length > 0
        ? `لديك ${contracts.length} عقد ينتهي خلال ${periodText} القادمة. تأكد من مراجعة التجديد أو الإخلاء في الوقت المناسب.`
        : `لا يوجد حالياً عقود تنتهي خلال ${periodText} القادمة لحسابك.`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'contracts',
      contracts,
    });
  }

  // 2.1) Get contract by ID
  if (intent === "get_contract_by_id") {
    const contractId = parseIntent(question).contractId;
    const contract = await Contract.findById(contractId)
      .populate("propertyId", "title city")
      .populate("tenantId", "name email")
      .populate("landlordId", "name email")
      .lean();

    if (!contract) {
      return res.json({
        success: true,
        intent,
        answer: "لم يتم العثور على العقد المطلوب.",
        dataType: 'contracts',
        contracts: [],
      });
    }

    // Check if user has access
    const tenantId = contract.tenantId?._id?.toString() || contract.tenantId?.toString();
    const landlordId = contract.landlordId?._id?.toString() || contract.landlordId?.toString();
    
    if (tenantId !== userId && landlordId !== userId && req.user.role !== "admin") {
      return res.json({
        success: true,
        intent,
        answer: "ليس لديك صلاحية لعرض هذا العقد.",
        dataType: 'contracts',
        contracts: [],
      });
    }

    const answer = `تفاصيل العقد:
- العقار: ${contract.propertyId?.title || "غير محدد"}
- الحالة: ${contract.status}
- مبلغ الإيجار: ${contract.rentAmount || 0}$
- تاريخ البداية: ${contract.startDate ? new Date(contract.startDate).toLocaleDateString("ar") : "غير محدد"}
- تاريخ النهاية: ${contract.endDate ? new Date(contract.endDate).toLocaleDateString("ar") : "غير محدد"}`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'contracts',
      contracts: [contract],
    });
  }

  // 2.2) Contracts for specific property
  if (intent === "contracts_for_property") {
    // Extract property name/ID from question
    const propertyNameMatch = question.match(/(?:عقار|property)\s+["']?([^"']+)["']?/i);
    let contracts = [];

    if (propertyNameMatch) {
      const propertyName = propertyNameMatch[1];
      const property = await Property.findOne({
        title: new RegExp(propertyName, "i"),
      }).lean();

      if (property) {
        contracts = await Contract.find({
          propertyId: property._id,
          $or: [{ tenantId: userId }, { landlordId: userId }],
        })
          .populate("propertyId", "title city")
          .populate("tenantId", "name")
          .populate("landlordId", "name")
          .lean();
      }
    } else {
      // Get all user contracts
      contracts = await Contract.find({
        $or: [{ tenantId: userId }, { landlordId: userId }],
      })
        .populate("propertyId", "title city")
        .populate("tenantId", "name")
        .populate("landlordId", "name")
        .lean();
    }

    const answer =
      contracts.length > 0
        ? `وجدت ${contracts.length} عقد مرتبط بالعقار المطلوب.`
        : "لا توجد عقود مرتبطة بالعقار المطلوب.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'contracts',
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

  // 3.1) Count questions in aiAssistant
  if (intent === "count_properties") {
    const count = await Property.countDocuments({
      status: "available",
      verified: true,
    });

    return res.json({
      success: true,
      intent,
      answer: `عدد العقارات المتاحة في النظام: ${count} عقار.`,
      dataType: 'count',
      count,
      type: 'properties',
    });
  }

  if (intent === "count_contracts") {
    const count = await Contract.countDocuments({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    });

    return res.json({
      success: true,
      intent,
      answer: `عدد العقود المرتبطة بك: ${count} عقد.`,
      dataType: 'count',
      count,
      type: 'contracts',
    });
  }

  if (intent === "count_payments") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();
    const contractIds = userContracts.map((c) => c._id);

    const count = await Payment.countDocuments({
      contractId: { $in: contractIds },
    });

    return res.json({
      success: true,
      intent,
      answer: `عدد الدفعات المرتبطة بك: ${count} دفعة.`,
      dataType: 'count',
      count,
      type: 'payments',
    });
  }

  if (intent === "count_users") {
    if (req.user.role !== "admin") {
      return res.json({
        success: true,
        intent,
        answer: "ليس لديك صلاحية لعرض عدد المستخدمين.",
        dataType: 'count',
      });
    }

    const count = await User.countDocuments();
    return res.json({
      success: true,
      intent,
      answer: `عدد المستخدمين في النظام: ${count} مستخدم.`,
      dataType: 'count',
      count,
      type: 'users',
    });
  }

  if (intent === "count_maintenance") {
    const count = await MaintenanceRequest.countDocuments({ tenantId: userId });
    return res.json({
      success: true,
      intent,
      answer: `عدد طلبات الصيانة لديك: ${count} طلب.`,
      dataType: 'count',
      count,
      type: 'maintenance',
    });
  }

  // 3.2) Get property by name
  if (intent === "get_property_by_name") {
    const propertyName = parseIntent(question).propertyName;
    const property = await Property.findOne({
      title: new RegExp(propertyName, "i"),
      status: "available",
      verified: true,
    })
      .populate("ownerId", "name email")
      .lean();

    if (!property) {
      return res.json({
        success: true,
        intent,
        answer: `لم يتم العثور على عقار باسم "${propertyName}".`,
        dataType: 'properties',
        properties: [],
      });
    }

    return res.json({
      success: true,
      intent,
      answer: `وجدت العقار "${property.title}" في ${property.city || "غير محدد"} بسعر ${property.price || 0}$.`,
      dataType: 'properties',
      properties: [property],
    });
  }

  // 3.3) User profile
  if (intent === "user_profile") {
    const user = await User.findById(userId).select("name email phone role").lean();
    
    if (!user) {
      return res.json({
        success: true,
        intent,
        answer: "لم يتم العثور على بيانات المستخدم.",
        dataType: 'profile',
      });
    }

    const answer = `بيانات حسابك:
- الاسم: ${user.name || "غير محدد"}
- البريد الإلكتروني: ${user.email || "غير محدد"}
- رقم الهاتف: ${user.phone || "غير محدد"}
- الدور: ${user.role === "tenant" ? "مستأجر" : user.role === "landlord" ? "مالك" : "أدمن"}`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'profile',
      user: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
    });
  }

  // 3.4) Financial summary
  if (intent === "financial_summary") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id propertyId")
      .lean();

    const contractIds = userContracts.map((c) => c._id);
    const propertyIds = userContracts.map((c) => c.propertyId).filter(Boolean);

    const [expenses, deposits, invoices, payments] = await Promise.all([
      Expense.find({
        $or: [
          { contractId: { $in: contractIds } },
          { propertyId: { $in: propertyIds } },
        ],
      })
        .lean()
        .catch(() => []),
      Deposit.find({ contractId: { $in: contractIds } })
        .lean()
        .catch(() => []),
      Invoice.find({ contractId: { $in: contractIds } })
        .lean()
        .catch(() => []),
      Payment.find({ contractId: { $in: contractIds } })
        .lean()
        .catch(() => []),
    ]);

    const totalExpenses = expenses.reduce((sum, e) => sum + (e.amount || 0), 0);
    const totalDeposits = deposits.reduce((sum, d) => sum + (d.amount || 0), 0);
    const totalInvoices = invoices.reduce((sum, i) => sum + (i.amount || 0), 0);
    const totalPaid = payments
      .filter((p) => p.status === "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);
    const totalPending = payments
      .filter((p) => p.status !== "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const answer = `ملخصك المالي:
- إجمالي المصاريف: ${totalExpenses}$
- إجمالي الودائع: ${totalDeposits}$
- إجمالي الفواتير: ${totalInvoices}$
- المدفوع: ${totalPaid}$
- المعلق: ${totalPending}$
- الرصيد الصافي: ${totalPaid - totalExpenses}$`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'financial',
      summary: {
        totalExpenses,
        totalDeposits,
        totalInvoices,
        totalPaid,
        totalPending,
        netBalance: totalPaid - totalExpenses,
      },
      expenses: expenses.slice(0, 10),
      deposits: deposits.slice(0, 10),
      invoices: invoices.slice(0, 10),
    });
  }

  // 3.5) Vague queries (أسئلة غامضة)
  if (intent === "vague_query") {
    const q = question.toLowerCase();
    
    // "بدي شقة حلوة" → أفضل العقارات
    if (q.includes("حلوة") || q.includes("حلو") || q.includes("nice") || q.includes("best")) {
      const properties = await Property.find({
        status: "available",
        verified: true,
      })
        .populate("ownerId", "name email")
        .sort({ price: 1 }) // أرخص أولاً
        .limit(10)
        .lean();

      return res.json({
        success: true,
        intent,
        answer: `إليك أفضل ${properties.length} عقار متاح في النظام:`,
        dataType: 'properties',
        properties,
      });
    }

    // "شو في جديد؟" → آخر العقارات/العقود/الإشعارات
    if (q.includes("جديد") || q.includes("new") || q.includes("latest")) {
      const [newProperties, newContracts, newNotifications] = await Promise.all([
        Property.find({
          status: "available",
          verified: true,
        })
          .sort({ createdAt: -1 })
          .limit(5)
          .lean(),
        Contract.find({
          $or: [{ tenantId: userId }, { landlordId: userId }],
        })
          .sort({ createdAt: -1 })
          .limit(5)
          .lean(),
        Notification.find({ recipientId: userId })
          .sort({ createdAt: -1 })
          .limit(5)
          .lean(),
      ]);

      const answer = `آخر التحديثات:
- ${newProperties.length} عقار جديد
- ${newContracts.length} عقد جديد
- ${newNotifications.length} إشعار جديد`;

      return res.json({
        success: true,
        intent,
        answer,
        dataType: 'general',
        properties: newProperties,
        contracts: newContracts,
        notifications: newNotifications,
      });
    }

    // "شو وضعي المالي؟" → ملخص مالي
    if (q.includes("وضعي") || q.includes("status") || q.includes("my status")) {
      // Redirect to financial_summary
      const userContracts = await Contract.find({
        $or: [{ tenantId: userId }, { landlordId: userId }],
      })
        .select("_id propertyId")
        .lean();

      const contractIds = userContracts.map((c) => c._id);
      const propertyIds = userContracts.map((c) => c.propertyId).filter(Boolean);

      const [expenses, deposits, invoices, payments] = await Promise.all([
        Expense.find({
          $or: [
            { contractId: { $in: contractIds } },
            { propertyId: { $in: propertyIds } },
          ],
        })
          .lean()
          .catch(() => []),
        Deposit.find({ contractId: { $in: contractIds } })
          .lean()
          .catch(() => []),
        Invoice.find({ contractId: { $in: contractIds } })
          .lean()
          .catch(() => []),
        Payment.find({ contractId: { $in: contractIds } })
          .lean()
          .catch(() => []),
      ]);

      const totalPaid = payments
        .filter((p) => p.status === "paid")
        .reduce((sum, p) => sum + (p.amount || 0), 0);
      const totalPending = payments
        .filter((p) => p.status !== "paid")
        .reduce((sum, p) => sum + (p.amount || 0), 0);

      const answer = `وضعك المالي:
- المدفوع: ${totalPaid}$
- المعلق: ${totalPending}$
- عدد العقود: ${userContracts.length}
- عدد الدفعات: ${payments.length}`;

      return res.json({
        success: true,
        intent,
        answer,
        dataType: 'financial',
        summary: {
          totalPaid,
          totalPending,
          contractsCount: userContracts.length,
          paymentsCount: payments.length,
        },
      });
    }

    // Default vague response - use smart context
    const userRole = req.user?.role || "tenant";
    const { systemPrompt } = await _buildSmartContext(
      userId,
      question,
      intent,
      userRole
    );

    const messages = [
      { role: "system", content: systemPrompt },
      { role: "user", content: question },
    ];

    const provider = getAIProvider();
    const aiResponse = await chatWithAIProvider(messages, {
      temperature: 0.4,
      max_tokens: 2000,
    });

    return res.json({
      success: true,
      intent,
      answer: aiResponse,
      dataType: 'general',
      provider: provider.type,
      model: provider.model,
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
      dataType: 'contracts',
      filters: { status: statusFilter || null },
      contracts,
    });
  }

  // 5) List all payments for current user's contracts (محسن)
  if (intent === "list_payments" || intent === "payments_for_contract") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();

    const contractIds = userContracts.map((c) => c._id);

    let query = {
      contractId: { $in: contractIds },
    };

    // ✅ Filter by date if specified
    const now = new Date();
    if (question.includes("هذا الشهر") || question.includes("الشهر")) {
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      query.date = { $gte: startOfMonth, $lte: now };
    } else if (question.includes("هذه السنة") || question.includes("السنة")) {
      const startOfYear = new Date(now.getFullYear(), 0, 1);
      query.date = { $gte: startOfYear, $lte: now };
    } else if (question.includes("اليوم")) {
      const startOfDay = new Date(now.setHours(0, 0, 0, 0));
      query.date = { $gte: startOfDay, $lte: now };
    }

    // ✅ Filter by status
    if (question.includes("مدفوعة") || question.includes("paid")) {
      query.status = "paid";
    } else if (question.includes("متأخرة") || question.includes("overdue")) {
      query.status = { $ne: "paid" };
      query.date = { $lt: now };
    }

    const payments = await Payment.find(query)
      .populate({
        path: "contractId",
        populate: [{ path: "propertyId", select: "title city" }],
      })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    // ✅ Calculate totals
    const totalPaid = payments
      .filter((p) => p.status === "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);
    const totalPending = payments
      .filter((p) => p.status !== "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const answer =
      payments.length > 0
        ? `تم العثور على ${payments.length} دفعة مرتبطة بعقودك.
- المدفوع: ${totalPaid}$
- المعلق: ${totalPending}$
يمكنك عرض تفاصيل كل دفعة وفتح شاشة العقد المرتبطة بها من واجهة الذكاء الاصطناعي.`
        : "لا يوجد أي دفعات مسجلة لعقودك حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'payments',
      payments,
      summary: {
        total: payments.length,
        totalPaid,
        totalPending,
      },
    });
  }

  // 5.1) Total paid amount
  if (intent === "total_paid") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();

    const contractIds = userContracts.map((c) => c._id);

    const payments = await Payment.find({
      contractId: { $in: contractIds },
      status: "paid",
    })
      .lean();

    const totalPaid = payments.reduce((sum, p) => sum + (p.amount || 0), 0);

    const answer = `إجمالي المبلغ المدفوع: ${totalPaid}$ من ${payments.length} دفعة.`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'financial',
      totalPaid,
      paymentsCount: payments.length,
    });
  }

  // 6) List maintenance requests for current user (محسن)
  if (intent === "list_maintenance" || intent === "maintenance_for_property") {
    let query = { tenantId: userId };

    // ✅ Filter by status
    if (question.includes("معلقة") || question.includes("pending")) {
      query.status = "pending";
    } else if (question.includes("مكتملة") || question.includes("completed")) {
      query.status = "completed";
    } else if (question.includes("قيد التنفيذ") || question.includes("in_progress")) {
      query.status = "in_progress";
    }

    // ✅ Filter by property if specified
    if (intent === "maintenance_for_property") {
      const propertyNameMatch = question.match(/(?:عقار|property)\s+["']?([^"']+)["']?/i);
      if (propertyNameMatch) {
        const propertyName = propertyNameMatch[1];
        const property = await Property.findOne({
          title: new RegExp(propertyName, "i"),
        }).lean();
        if (property) {
          query.propertyId = property._id;
        }
      }
    }

    // ✅ Filter by date
    const now = new Date();
    if (question.includes("هذا الشهر") || question.includes("الشهر")) {
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      query.createdAt = { $gte: startOfMonth, $lte: now };
    }

    const requests = await MaintenanceRequest.find(query)
      .populate("propertyId", "title city")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    const pendingCount = requests.filter((r) => r.status === "pending").length;
    const completedCount = requests.filter((r) => r.status === "completed").length;

    const answer =
      requests.length > 0
        ? `لديك ${requests.length} طلب/طلبات صيانة (${pendingCount} معلقة، ${completedCount} مكتملة). يمكنك فتح أي طلب من شاشة الذكاء الاصطناعي لمتابعة حالته.`
        : "لا يوجد لديك طلبات صيانة مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'maintenance',
      maintenanceRequests: requests,
    });
  }

  // 6.1) Get maintenance request by ID
  if (intent === "get_maintenance_by_id") {
    const maintenanceId = parseIntent(question).maintenanceId;
    const request = await MaintenanceRequest.findById(maintenanceId)
      .populate("propertyId", "title city")
      .populate("tenantId", "name")
      .lean();

    if (!request) {
      return res.json({
        success: true,
        intent,
        answer: "لم يتم العثور على طلب الصيانة المطلوب.",
        dataType: 'maintenance',
        maintenanceRequests: [],
      });
    }

    // Check access
    const tenantId = request.tenantId?._id?.toString() || request.tenantId?.toString();
    if (tenantId !== userId && req.user.role !== "admin" && req.user.role !== "landlord") {
      return res.json({
        success: true,
        intent,
        answer: "ليس لديك صلاحية لعرض هذا الطلب.",
        dataType: 'maintenance',
        maintenanceRequests: [],
      });
    }

    const answer = `تفاصيل طلب الصيانة رقم ${maintenanceId}:
- العقار: ${request.propertyId?.title || "غير محدد"}
- الحالة: ${request.status}
- الوصف: ${request.description || "غير محدد"}
- تاريخ الطلب: ${request.createdAt ? new Date(request.createdAt).toLocaleDateString("ar") : "غير محدد"}`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'maintenance',
      maintenanceRequests: [request],
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
      dataType: 'complaints',
      complaints,
    });
  }

  // 8) List notifications for current user (محسن)
  if (intent === "list_notifications") {
    let query = { recipientId: userId };

    // ✅ Filter by read status
    if (question.includes("غير مقروء") || question.includes("unread")) {
      query.read = false;
    } else if (question.includes("مقروء") || question.includes("read")) {
      query.read = true;
    }

    // ✅ Filter by type
    if (question.includes("عقود") || question.includes("contract")) {
      query.type = "contract";
    } else if (question.includes("دفعات") || question.includes("payment")) {
      query.type = "payment";
    } else if (question.includes("صيانة") || question.includes("maintenance")) {
      query.type = "maintenance";
    }

    const notifs = await Notification.find(query)
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
      dataType: 'notifications',
      notifications: notifs,
      unreadCount,
    });
  }

  // 8.1) Count questions
  if (intent === "count_properties") {
    const count = await Property.countDocuments({
      status: "available",
      verified: true,
    });

    return res.json({
      success: true,
      intent,
      answer: `عدد العقارات المتاحة في النظام: ${count} عقار.`,
      dataType: 'count',
      count,
      type: 'properties',
    });
  }

  if (intent === "count_contracts") {
    const count = await Contract.countDocuments({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    });

    return res.json({
      success: true,
      intent,
      answer: `عدد العقود المرتبطة بك: ${count} عقد.`,
      dataType: 'count',
      count,
      type: 'contracts',
    });
  }

  if (intent === "count_payments") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();
    const contractIds = userContracts.map((c) => c._id);

    const count = await Payment.countDocuments({
      contractId: { $in: contractIds },
    });

    return res.json({
      success: true,
      intent,
      answer: `عدد الدفعات المرتبطة بك: ${count} دفعة.`,
      dataType: 'count',
      count,
      type: 'payments',
    });
  }

  if (intent === "count_users") {
    if (req.user.role !== "admin") {
      return res.json({
        success: true,
        intent,
        answer: "ليس لديك صلاحية لعرض عدد المستخدمين.",
        dataType: 'count',
      });
    }

    const count = await User.countDocuments();
    return res.json({
      success: true,
      intent,
      answer: `عدد المستخدمين في النظام: ${count} مستخدم.`,
      dataType: 'count',
      count,
      type: 'users',
    });
  }

  if (intent === "count_maintenance") {
    const count = await MaintenanceRequest.countDocuments({ tenantId: userId });
    return res.json({
      success: true,
      intent,
      answer: `عدد طلبات الصيانة لديك: ${count} طلب.`,
      dataType: 'count',
      count,
      type: 'maintenance',
    });
  }

  // 8.2) Get property by name
  if (intent === "get_property_by_name") {
    const propertyName = parseIntent(question).propertyName;
    const property = await Property.findOne({
      title: new RegExp(propertyName, "i"),
      status: "available",
      verified: true,
    })
      .populate("ownerId", "name email")
      .lean();

    if (!property) {
      return res.json({
        success: true,
        intent,
        answer: `لم يتم العثور على عقار باسم "${propertyName}".`,
        dataType: 'properties',
        properties: [],
      });
    }

    return res.json({
      success: true,
      intent,
      answer: `وجدت العقار "${property.title}" في ${property.city || "غير محدد"} بسعر ${property.price || 0}$.`,
      dataType: 'properties',
      properties: [property],
    });
  }

  // 8.3) User profile
  if (intent === "user_profile") {
    const user = await User.findById(userId).select("name email phone role").lean();
    
    if (!user) {
      return res.json({
        success: true,
        intent,
        answer: "لم يتم العثور على بيانات المستخدم.",
        dataType: 'profile',
      });
    }

    const answer = `بيانات حسابك:
- الاسم: ${user.name || "غير محدد"}
- البريد الإلكتروني: ${user.email || "غير محدد"}
- رقم الهاتف: ${user.phone || "غير محدد"}
- الدور: ${user.role === "tenant" ? "مستأجر" : user.role === "landlord" ? "مالك" : "أدمن"}`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'profile',
      user: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
    });
  }

  // 8.4) Financial summary
  if (intent === "financial_summary") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id propertyId")
      .lean();

    const contractIds = userContracts.map((c) => c._id);
    const propertyIds = userContracts.map((c) => c.propertyId).filter(Boolean);

    const [expenses, deposits, invoices, payments] = await Promise.all([
      Expense.find({
        $or: [
          { contractId: { $in: contractIds } },
          { propertyId: { $in: propertyIds } },
        ],
      })
        .lean()
        .catch(() => []),
      Deposit.find({ contractId: { $in: contractIds } })
        .lean()
        .catch(() => []),
      Invoice.find({ contractId: { $in: contractIds } })
        .lean()
        .catch(() => []),
      Payment.find({ contractId: { $in: contractIds } })
        .lean()
        .catch(() => []),
    ]);

    const totalExpenses = expenses.reduce((sum, e) => sum + (e.amount || 0), 0);
    const totalDeposits = deposits.reduce((sum, d) => sum + (d.amount || 0), 0);
    const totalInvoices = invoices.reduce((sum, i) => sum + (i.amount || 0), 0);
    const totalPaid = payments
      .filter((p) => p.status === "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);
    const totalPending = payments
      .filter((p) => p.status !== "paid")
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const answer = `ملخصك المالي:
- إجمالي المصاريف: ${totalExpenses}$
- إجمالي الودائع: ${totalDeposits}$
- إجمالي الفواتير: ${totalInvoices}$
- المدفوع: ${totalPaid}$
- المعلق: ${totalPending}$
- الرصيد الصافي: ${totalPaid - totalExpenses}$`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'financial',
      summary: {
        totalExpenses,
        totalDeposits,
        totalInvoices,
        totalPaid,
        totalPending,
        netBalance: totalPaid - totalExpenses,
      },
      expenses: expenses.slice(0, 10),
      deposits: deposits.slice(0, 10),
      invoices: invoices.slice(0, 10),
    });
  }

  // 8.5) Vague queries (أسئلة غامضة)
  if (intent === "vague_query") {
    const q = question.toLowerCase();
    
    // "بدي شقة حلوة" → أفضل العقارات
    if (q.includes("حلوة") || q.includes("حلو") || q.includes("nice") || q.includes("best")) {
      const properties = await Property.find({
        status: "available",
        verified: true,
      })
        .populate("ownerId", "name email")
        .sort({ price: 1 }) // أرخص أولاً
        .limit(10)
        .lean();

      return res.json({
        success: true,
        intent,
        answer: `إليك أفضل ${properties.length} عقار متاح في النظام:`,
        dataType: 'properties',
        properties,
      });
    }

    // "شو في جديد؟" → آخر العقارات/العقود/الإشعارات
    if (q.includes("جديد") || q.includes("new") || q.includes("latest")) {
      const [newProperties, newContracts, newNotifications] = await Promise.all([
        Property.find({
          status: "available",
          verified: true,
        })
          .sort({ createdAt: -1 })
          .limit(5)
          .lean(),
        Contract.find({
          $or: [{ tenantId: userId }, { landlordId: userId }],
        })
          .sort({ createdAt: -1 })
          .limit(5)
          .lean(),
        Notification.find({ recipientId: userId })
          .sort({ createdAt: -1 })
          .limit(5)
          .lean(),
      ]);

      const answer = `آخر التحديثات:
- ${newProperties.length} عقار جديد
- ${newContracts.length} عقد جديد
- ${newNotifications.length} إشعار جديد`;

      return res.json({
        success: true,
        intent,
        answer,
        dataType: 'general',
        properties: newProperties,
        contracts: newContracts,
        notifications: newNotifications,
      });
    }

    // "شو وضعي المالي؟" → ملخص مالي
    if (q.includes("وضعي") || q.includes("status") || q.includes("my status")) {
      return res.json({
        success: true,
        intent: "financial_summary",
        answer: "جارٍ تحضير ملخصك المالي...",
        dataType: 'financial',
      });
    }

    // Default vague response
    const { systemPrompt, dbContext } = await _buildSmartContext(
      userId,
      question,
      intent,
      req.user?.role || "tenant"
    );

    const messages = [
      { role: "system", content: systemPrompt },
      { role: "user", content: question },
    ];

    const provider = getAIProvider();
    const aiResponse = await chatWithAIProvider(messages, {
      temperature: 0.4,
      max_tokens: 2000,
    });

    return res.json({
      success: true,
      intent,
      answer: aiResponse,
      dataType: 'general',
      provider: provider.type,
      model: provider.model,
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
        .populate("contractId", "propertyId")
        .populate("propertyId", "title city")
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .catch(() => []),
      Deposit.find({ contractId: { $in: contractIds } })
        .populate("contractId", "propertyId")
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .catch(() => []),
      Invoice.find({ contractId: { $in: contractIds } })
        .populate("contractId", "propertyId")
        .sort({ createdAt: -1 })
        .limit(50)
        .lean()
        .catch(() => []),
    ]);

    const answer = `ملخص العمليات المالية المرتبطة بك:
- عدد المصاريف: ${expenses.length}
- عدد الودائع: ${deposits.length}
- عدد الفواتير: ${invoices.length}

يمكنك الضغط على أي عنصر أدناه للانتقال إلى شاشة التفاصيل.`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'financial',
      expenses,
      deposits,
      invoices,
    });
  }

  // 9.1) List expenses only
  if (intent === "list_expenses") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id propertyId")
      .lean();

    const contractIds = userContracts.map((c) => c._id);
    const propertyIds = userContracts
      .map((c) => c.propertyId)
      .filter(Boolean);

    const expenses = await Expense.find({
      $or: [
        { contractId: { $in: contractIds } },
        { propertyId: { $in: propertyIds } },
      ],
    })
      .populate("contractId", "propertyId")
      .populate("propertyId", "title city")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean()
      .catch(() => []);

    const answer =
      expenses.length > 0
        ? `لديك ${expenses.length} مصروف/مصاريف. يمكنك الضغط على أي مصروف أدناه لعرض تفاصيله.`
        : "لا يوجد لديك مصاريف مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'expenses',
      expenses,
    });
  }

  // 9.2) List deposits only
  if (intent === "list_deposits") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();

    const contractIds = userContracts.map((c) => c._id);

    const deposits = await Deposit.find({ contractId: { $in: contractIds } })
      .populate("contractId", "propertyId")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean()
      .catch(() => []);

    const answer =
      deposits.length > 0
        ? `لديك ${deposits.length} وديعة/ودائع. يمكنك الضغط على أي وديعة أدناه لعرض تفاصيلها.`
        : "لا يوجد لديك ودائع مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'deposits',
      deposits,
    });
  }

  // 9.3) List invoices only
  if (intent === "list_invoices") {
    const userContracts = await Contract.find({
      $or: [{ tenantId: userId }, { landlordId: userId }],
    })
      .select("_id")
      .lean();

    const contractIds = userContracts.map((c) => c._id);

    const invoices = await Invoice.find({ contractId: { $in: contractIds } })
      .populate("contractId", "propertyId")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean()
      .catch(() => []);

    const answer =
      invoices.length > 0
        ? `لديك ${invoices.length} فاتورة/فواتير. يمكنك الضغط على أي فاتورة أدناه لعرض تفاصيلها.`
        : "لا يوجد لديك فواتير مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'invoices',
      invoices,
    });
  }

  // 9.4) List reviews
  if (intent === "list_reviews") {
    const reviews = await Review.find({ userId: userId })
      .populate("propertyId", "title city")
      .sort({ createdAt: -1 })
      .limit(50)
      .lean()
      .catch(() => []);

    const answer =
      reviews.length > 0
        ? `لديك ${reviews.length} تقييم/تقييمات. يمكنك الضغط على أي تقييم أدناه لعرض تفاصيله.`
        : "لا يوجد لديك تقييمات مسجلة حالياً.";

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'reviews',
      reviews,
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

  // 11) Communication/Contact help
  if (intent === "communication_help") {
    const answer = `يمكنك التواصل مع صاحب العقار في تطبيق SHAQATI بعدة طرق:

1. **من صفحة تفاصيل العقار:**
   - افتح أي عقار من القائمة
   - اضغط على زر "تواصل مع المالك" أو "Contact Owner"
   - يمكنك إرسال رسالة مباشرة

2. **من خلال نظام المحادثة:**
   - اذهب إلى شاشة المحادثات (Chat)
   - ابحث عن المالك أو اختره من القائمة
   - ابدأ محادثة جديدة

3. **من خلال طلب عقد:**
   - عند طلب عقد إيجار لعقار
   - سيتم إنشاء قناة تواصل تلقائياً بينك وبين المالك

**ملاحظة:** جميع الرسائل آمنة ومشفرة، ويمكنك متابعة المحادثات من أي مكان في التطبيق.`;

    return res.json({
      success: true,
      intent,
      answer,
      dataType: 'help',
    });
  }

  // 12) How-to questions
  if (intent === "how_to") {
    const userRole = req.user?.role || "tenant";
    
    // ✅ استخدام السياق الذكي
    const { systemPrompt } = await _buildSmartContext(
      userId,
      question,
      intent,
      userRole
    );

    const enhancedPrompt = `${systemPrompt}

**تعليمات خاصة لأسئلة "كيف":**
- كن واضحاً ومفصلاً في الشرح
- استخدم خطوات مرقمة عند الحاجة
- اذكر أسماء الشاشات والأزرار بدقة
- استخدم أمثلة من البيانات الفعلية عندما يكون ذلك ممكناً
- إذا كان السؤال عن ميزة موجودة، اشرحها بالتفصيل مع ذكر المسار الكامل

**أجب على السؤال التالي بشكل مفصل وواضح:**`;

    const messages = [
      { role: "system", content: enhancedPrompt },
      { role: "user", content: question },
    ];

    const provider = getAIProvider();
    const aiResponse = await chatWithAIProvider(messages, {
      temperature: 0.3,
      max_tokens: 2500,
    });

    return res.json({
      success: true,
      intent,
      answer: aiResponse,
      dataType: 'help',
      provider: provider.type,
      model: provider.model,
    });
  }

  // 13) What/Where questions
  if (intent === "what_where") {
    const userRole = req.user?.role || "tenant";
    
    // ✅ استخدام السياق الذكي
    const { systemPrompt, dbContext } = await _buildSmartContext(
      userId,
      question,
      intent,
      userRole
    );

    const enhancedPrompt = `${systemPrompt}

**تعليمات خاصة لأسئلة "ماذا" و"أين":**
- كن دقيقاً ومباشراً
- استخدم البيانات الفعلية من قاعدة البيانات أعلاه
- اذكر الأسماء والأماكن بدقة
- إذا كان السؤال عن موقع أو مكان، اذكر المسار الكامل
- إذا كان السؤال عن بيانات، استخدم البيانات الحقيقية أعلاه

**أجب على السؤال التالي بشكل دقيق:**`;

    const messages = [
      { role: "system", content: enhancedPrompt },
      { role: "user", content: question },
    ];

    const provider = getAIProvider();
    const aiResponse = await chatWithAIProvider(messages, {
      temperature: 0.2,
      max_tokens: 2500,
    });

    // ✅ إرجاع البيانات الفعلية
    const responseData = {};
    if (dbContext.properties.length > 0) responseData.properties = dbContext.properties;
    if (dbContext.contracts.length > 0) responseData.contracts = dbContext.contracts;
    if (dbContext.payments.length > 0) responseData.payments = dbContext.payments;

    return res.json({
      success: true,
      intent,
      answer: aiResponse,
      dataType: 'help',
      ...responseData,
      provider: provider.type,
      model: provider.model,
    });
  }

  // 14) Help/Support questions
  if (intent === "help_support") {
    const userRole = req.user?.role || "tenant";
    
    // ✅ استخدام السياق الذكي
    const { systemPrompt } = await _buildSmartContext(
      userId,
      question,
      intent,
      userRole
    );

    const enhancedPrompt = `${systemPrompt}

**تعليمات خاصة لأسئلة المساعدة والدعم:**
- كن مفيداً ومتعاطفاً
- قدم حلول عملية وخطوات واضحة
- إذا كان هناك مشكلة تقنية، اشرح كيفية حلها بالتفصيل
- استخدم المعلومات من ملفات التوثيق (خاصة TROUBLESHOOTING.md)
- إذا لم تستطع حل المشكلة، اقترح التواصل مع الدعم الفني
- استخدم أمثلة من البيانات الفعلية عندما يكون ذلك مفيداً

**أجب على السؤال التالي بشكل مفيد:**`;

    const messages = [
      { role: "system", content: enhancedPrompt },
      { role: "user", content: question },
    ];

    const provider = getAIProvider();
    const aiResponse = await chatWithAIProvider(messages, {
      temperature: 0.3,
      max_tokens: 2500,
    });

    return res.json({
      success: true,
      intent,
      answer: aiResponse,
      dataType: 'help',
      provider: provider.type,
      model: provider.model,
    });
  }

  // 15) General questions → use smart context (System Prompt + Knowledge + DB Data)
  const userRole = req.user?.role || "tenant";
  
  // ✅ بناء السياق الذكي الكامل
  const { systemPrompt, dbContext } = await _buildSmartContext(
    userId,
    question,
    intent,
    userRole
  );

  const messages = [
    { role: "system", content: systemPrompt },
    { role: "user", content: question },
  ];

  const provider = getAIProvider();
  const aiResponse = await chatWithAIProvider(messages, {
    temperature: 0.4, // ✅ معتدل ليكون ذكياً وطبيعياً
    max_tokens: 2500, // ✅ زيادة للسماح بإجابات مفصلة
  });

  // ✅ إرجاع البيانات الفعلية مع الإجابة
  const responseData = {};
  if (dbContext.properties.length > 0) {
    responseData.properties = dbContext.properties;
  }
  if (dbContext.contracts.length > 0) {
    responseData.contracts = dbContext.contracts;
  }
  if (dbContext.payments.length > 0) {
    responseData.payments = dbContext.payments;
  }
  if (dbContext.maintenance.length > 0) {
    responseData.maintenanceRequests = dbContext.maintenance;
  }
  if (dbContext.expenses.length > 0) {
    responseData.expenses = dbContext.expenses;
  }
  if (dbContext.deposits.length > 0) {
    responseData.deposits = dbContext.deposits;
  }
  if (dbContext.invoices.length > 0) {
    responseData.invoices = dbContext.invoices;
  }
  if (dbContext.complaints.length > 0) {
    responseData.complaints = dbContext.complaints;
  }

  return res.json({
    success: true,
    intent,
    answer: aiResponse,
    dataType: 'general',
    ...responseData, // ✅ إرجاع البيانات الفعلية
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

/**
 * 🔥 DB Context Injection - يجلب البيانات حسب السؤال
 * هذا يجعل AI يرى بيانات حقيقية من قاعدة البيانات
 */
async function _buildSmartDBContext(userId, question, intent) {
  const q = (question || "").toLowerCase();
  const context = {
    properties: [],
    contracts: [],
    payments: [],
    maintenance: [],
    expenses: [],
    deposits: [],
    invoices: [],
    complaints: [],
    notifications: [],
    summary: "",
  };

  try {
    // ✅ إذا السؤال عن العقارات
    if (
      intent === "search_properties" ||
      intent === "search_properties_on_map" ||
      q.includes("عقار") ||
      q.includes("عقارات") ||
      q.includes("property")
    ) {
      const properties = await Property.find({
        status: "available",
        verified: true,
      })
        .populate("ownerId", "name email")
        .limit(20)
        .lean();
      context.properties = properties;
    }

    // ✅ إذا السؤال عن العقود
    if (
      intent === "list_contracts" ||
      intent === "contracts_expiring_soon" ||
      q.includes("عقد") ||
      q.includes("عقود") ||
      q.includes("contract")
    ) {
      const contracts = await Contract.find({
        $or: [{ tenantId: userId }, { landlordId: userId }],
      })
        .populate("propertyId", "title city")
        .populate("tenantId", "name")
        .populate("landlordId", "name")
        .limit(20)
        .lean();
      context.contracts = contracts;
    }

    // ✅ إذا السؤال عن الدفعات
    if (
      intent === "list_payments" ||
      intent === "late_payments" ||
      q.includes("دفعة") ||
      q.includes("دفعات") ||
      q.includes("payment")
    ) {
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
        .limit(20)
        .lean();
      context.payments = payments;
    }

    // ✅ إذا السؤال عن الصيانة
    if (
      intent === "list_maintenance" ||
      q.includes("صيانة") ||
      q.includes("maintenance")
    ) {
      const maintenance = await MaintenanceRequest.find({
        tenantId: userId,
      })
        .populate("propertyId", "title city")
        .limit(20)
        .lean();
      context.maintenance = maintenance;
    }

    // ✅ إذا السؤال عن المصاريف
    if (
      intent === "list_expenses" ||
      intent === "list_financial" ||
      q.includes("مصروف") ||
      q.includes("مصاريف") ||
      q.includes("expense")
    ) {
      const userContracts = await Contract.find({
        $or: [{ tenantId: userId }, { landlordId: userId }],
      })
        .select("_id propertyId")
        .lean();
      const contractIds = userContracts.map((c) => c._id);
      const propertyIds = userContracts
        .map((c) => c.propertyId)
        .filter(Boolean);

      const expenses = await Expense.find({
        $or: [
          { contractId: { $in: contractIds } },
          { propertyId: { $in: propertyIds } },
        ],
      })
        .populate("contractId", "propertyId")
        .populate("propertyId", "title city")
        .limit(20)
        .lean();
      context.expenses = expenses;
    }

    // ✅ إذا السؤال عن الودائع
    if (
      intent === "list_deposits" ||
      intent === "list_financial" ||
      q.includes("وديعة") ||
      q.includes("ودائع") ||
      q.includes("deposit")
    ) {
      const userContracts = await Contract.find({
        $or: [{ tenantId: userId }, { landlordId: userId }],
      })
        .select("_id")
        .lean();
      const contractIds = userContracts.map((c) => c._id);

      const deposits = await Deposit.find({
        contractId: { $in: contractIds },
      })
        .populate("contractId", "propertyId")
        .limit(20)
        .lean();
      context.deposits = deposits;
    }

    // ✅ إذا السؤال عن الفواتير
    if (
      intent === "list_invoices" ||
      intent === "list_financial" ||
      q.includes("فاتورة") ||
      q.includes("فواتير") ||
      q.includes("invoice")
    ) {
      const userContracts = await Contract.find({
        $or: [{ tenantId: userId }, { landlordId: userId }],
      })
        .select("_id")
        .lean();
      const contractIds = userContracts.map((c) => c._id);

      const invoices = await Invoice.find({
        contractId: { $in: contractIds },
      })
        .populate("contractId", "propertyId")
        .limit(20)
        .lean();
      context.invoices = invoices;
    }

    // ✅ إذا السؤال عن الشكاوى
    if (
      intent === "list_complaints" ||
      q.includes("شكوى") ||
      q.includes("شكاوى") ||
      q.includes("complaint")
    ) {
      const complaints = await Complaint.find({
        submittedBy: userId,
      })
        .limit(20)
        .lean();
      context.complaints = complaints;
    }

    // ✅ بناء ملخص نصي للسياق
    const summaryParts = [];
    if (context.properties.length > 0) {
      summaryParts.push(
        `عقارات متاحة: ${context.properties.length} (${context.properties
          .slice(0, 3)
          .map((p) => `${p.title} - ${p.city} - ${p.price}$`)
          .join(", ")})`
      );
    }
    if (context.contracts.length > 0) {
      summaryParts.push(
        `عقود: ${context.contracts.length} (${context.contracts
          .slice(0, 3)
          .map((c) => `عقد ${c.status}`)
          .join(", ")})`
      );
    }
    if (context.payments.length > 0) {
      summaryParts.push(
        `دفعات: ${context.payments.length} (${context.payments
          .slice(0, 3)
          .map((p) => `${p.amount}$ - ${p.status}`)
          .join(", ")})`
      );
    }
    if (context.maintenance.length > 0) {
      summaryParts.push(`طلبات صيانة: ${context.maintenance.length}`);
    }
    if (context.expenses.length > 0) {
      summaryParts.push(`مصاريف: ${context.expenses.length}`);
    }
    if (context.deposits.length > 0) {
      summaryParts.push(`ودائع: ${context.deposits.length}`);
    }
    if (context.invoices.length > 0) {
      summaryParts.push(`فواتير: ${context.invoices.length}`);
    }

    context.summary = summaryParts.join("\n");
  } catch (error) {
    console.error("❌ Error building DB context:", error);
  }

  return context;
}

/**
 * 🔥 بناء السياق الذكي الكامل (System Prompt + Knowledge + DB Data)
 */
async function _buildSmartContext(userId, question, intent, userRole) {
  // 1️⃣ System Prompt الشامل
  const systemPrompt = getSHAQATISystemPrompt();
  const rolePrompt = getUserRolePrompt(userRole, userId);

  // 2️⃣ Knowledge Base
  const knowledgeContent = loadKnowledgeFiles();

  // 3️⃣ Database Snapshot العام
  const dbSnapshot = await _buildDatabaseSnapshot(userId);

  // 4️⃣ DB Context Injection حسب السؤال
  const dbContext = await _buildSmartDBContext(userId, question, intent);

  // 5️⃣ سياق المستخدم الإضافي
  const userContracts = await Contract.find({
    $or: [{ tenantId: userId }, { landlordId: userId }],
  })
    .select("status propertyId")
    .limit(5)
    .lean()
    .catch(() => []);

  const userProperties = await Property.find({
    ownerId: userId,
  })
    .select("title city status")
    .limit(5)
    .lean()
    .catch(() => []);

  const userContext = `
**سياق المستخدم الحالي:**
- عدد العقود: ${userContracts.length}
- عدد العقارات (للمالك): ${userProperties.length}
- آخر عقود: ${userContracts.slice(0, 3).map((c) => c.status).join(", ")}
`;

  // 6️⃣ بناء السياق الكامل
  const fullContext = `${systemPrompt}

${rolePrompt}

**قاعدة البيانات الحية (حتى لحظة هذا الطلب):**
${dbSnapshot.globalSummary}

${dbSnapshot.userSummary}

${userContext}

**بيانات حقيقية من قاعدة البيانات (حسب السؤال):**
${dbContext.summary || "لا توجد بيانات محددة"}

${dbContext.properties.length > 0
  ? `\n**العقارات المتاحة:**\n${dbContext.properties
      .slice(0, 10)
      .map(
        (p, i) =>
          `${i + 1}. ${p.title || "عقار"} - ${p.city || "غير محدد"} - ${p.price || 0}$ - ${p.bedrooms || 0} غرف - ${p.bathrooms || 0} حمام`
      )
      .join("\n")}`
  : ""}

${dbContext.contracts.length > 0
  ? `\n**عقودك:**\n${dbContext.contracts
      .slice(0, 10)
      .map(
        (c, i) =>
          `${i + 1}. عقد ${c.status} - ${c.propertyId?.title || "عقار"} - ${c.rentAmount || 0}$`
      )
      .join("\n")}`
  : ""}

${dbContext.payments.length > 0
  ? `\n**دفعاتك:**\n${dbContext.payments
      .slice(0, 10)
      .map(
        (p, i) =>
          `${i + 1}. ${p.amount || 0}$ - ${p.status} - ${p.date ? new Date(p.date).toLocaleDateString("ar") : "غير محدد"}`
      )
      .join("\n")}`
  : ""}

**معلومات المشروع الكاملة (من ملفات التوثيق):**
${knowledgeContent}

**قدراتك:**
- فهم جميع أنواع الأسئلة (كيف، ماذا، أين، لماذا)
- الوصول إلى جميع البيانات من قاعدة البيانات
- معرفة جميع الـ APIs والـ endpoints
- فهم جميع الشاشات والميزات
- تقديم إجابات دقيقة ومفيدة بناءً على البيانات الفعلية

**قواعد الإجابة:**
1. أجب باللغة العربية دائماً
2. كن ذكياً ومفيداً - استخدم كل المعلومات المتاحة (System Prompt + Knowledge + DB Data)
3. إذا كان السؤال عن بيانات، استخدم البيانات الفعلية من قاعدة البيانات أعلاه
4. إذا كان السؤال عن ميزة، اشرحها بالتفصيل مع ذكر أسماء الشاشات
5. إذا كان السؤال عن API أو endpoint، اذكر المسار الكامل
6. كن طبيعياً في الإجابة - لا تكن روبوتياً
7. إذا لم تعرف الإجابة، اعترف بذلك بصراحة
8. استخدم البيانات الحقيقية أعلاه للإجابة بدقة

**أجب على السؤال التالي بشكل ذكي ومفيد بناءً على جميع المعلومات المتاحة:**`;

  return {
    systemPrompt: fullContext,
    dbContext, // ✅ نرجع DB Context أيضاً للاستخدام في الـ response
  };
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
