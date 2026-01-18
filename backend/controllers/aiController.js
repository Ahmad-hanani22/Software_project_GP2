// controllers/aiController.js
import asyncHandler from "express-async-handler";
import { protect } from "../middleware/authMiddleware.js";
import { chatWithOllama, checkOllamaHealth } from "../utils/localAI.js";
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
    if (process.env.NODE_ENV === "development") {
      console.log("📤 إرسال طلب إلى Ollama...");
      console.log("📝 Messages count:", messages.length);
      console.log("📚 Knowledge size:", knowledgeContent.length, "characters");
    }

    // إرسال الطلب إلى Ollama
    // ✅ temperature منخفض جداً (0.1) لضمان الالتزام الصارم بالقواعد
    const finalResponse = await chatWithOllama(messages, {
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
        model: process.env.OLLAMA_MODEL || "llama2",
      });
    }

    res.json({
      success: true,
      response: finalResponse,
      model: process.env.OLLAMA_MODEL || "llama2",
    });
  } catch (error) {
    console.error("❌ Ollama API Error:", error);
    console.error("❌ Error Details:", {
      message: error.message,
      code: error.code,
    });

    // معالجة الأخطاء مع رسائل واضحة
    let errorMessage = "حدث خطأ أثناء الاتصال بـ Ollama";
    let statusCode = 500;
    let helpMessage = "";

    if (error.code === 'ECONNREFUSED' || error.message?.includes('ECONNREFUSED') || error.message?.includes('Ollama is not running')) {
      errorMessage = "❌ Ollama غير شغال";
      statusCode = 503;
      helpMessage = `🔧 خطوات الحل السريع:

1️⃣ افتح Terminal/PowerShell جديد
2️⃣ اكتب: ollama serve
3️⃣ اترك Terminal مفتوحاً (Ollama يجب أن يبقى يعمل)
4️⃣ في Terminal آخر: ollama pull llama2
5️⃣ انتظر حتى ينتهي التحميل
6️⃣ جرب مرة أخرى

💡 نصيحة: تأكد أن Ollama مثبت على جهازك
📖 للمزيد: راجع ملف OLLAMA_SETUP.md`.trim();
    } else if (error.message?.includes('timeout') || error.message?.includes('مهلة الاتصال') || error.message?.includes('AbortError')) {
      errorMessage = "⏱️ انتهت مهلة الاتصال";
      statusCode = 504;
      helpMessage = `الموديل قد يكون كبيراً أو بطيئاً.

🔧 حلول سريعة:
1. استخدم موديل أصغر: ollama pull llama2
2. أو انتظر قليلاً - الموديلات الكبيرة تحتاج وقت أطول
3. تأكد أن جهازك لديه RAM كافية (llama2 يحتاج ~4GB)`;
    } else if (error.message?.includes('model') || error.message?.includes('not found')) {
      errorMessage = "❌ الموديل غير موجود";
      statusCode = 404;
      helpMessage = `
🔧 خطوات الحل:
1. افتح Terminal
2. اكتب: ollama pull llama2
3. انتظر حتى ينتهي التحميل
4. جرب مرة أخرى
      `.trim();
    } else {
      errorMessage = `خطأ: ${error.message || 'خطأ غير معروف'}`;
      helpMessage = "يرجى التحقق من أن Ollama يعمل وأن الموديل مثبت";
    }

    res.status(statusCode).json({
      success: false,
      message: errorMessage,
      help: helpMessage || undefined,
      code: error.code || 'unknown_error',
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
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

    // Apply filters from request
    if (filters.budget) {
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
      aiResponse = await chatWithOllama(messages, {
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
 * فحص حالة AI Service
 */
export const checkAIHealth = asyncHandler(async (req, res) => {
  const knowledgeContent = loadKnowledgeFiles();
  const hasKnowledge = knowledgeContent.length > 0;
  
  // فحص حالة Ollama
  const ollamaHealth = await checkOllamaHealth();

  res.json({
    success: true,
    health: {
      ollamaAvailable: ollamaHealth.available,
      ollamaModels: ollamaHealth.models || [],
      targetModel: ollamaHealth.targetModel || "llama2",
      hasTargetModel: ollamaHealth.hasTargetModel || false,
      knowledgeFilesLoaded: hasKnowledge,
      knowledgeSize: knowledgeContent.length,
      provider: "Ollama (Local LLM)",
      status: ollamaHealth.available ? "ready" : "not_configured",
    },
    message: ollamaHealth.available
      ? hasKnowledge 
        ? "AI Service جاهز للاستخدام مع ملفات المعرفة"
        : "AI Service جاهز لكن بدون ملفات معرفة"
      : ollamaHealth.error || "يرجى تشغيل Ollama. استخدم: ollama serve",
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
