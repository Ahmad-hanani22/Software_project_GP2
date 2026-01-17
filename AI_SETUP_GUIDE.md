# 🧠 دليل إعداد AI Assistant لـ SHAQATI

هذا الدليل يشرح كيفية إعداد نظام AI Assistant المتكامل مع مشروع SHAQATI.

---

## ✅ ما تم إنجازه

1. ✅ إنشاء مجلد `ai_knowledge/` مع 4 ملفات معرفة:
   - `README.md` - نظرة عامة على المشروع
   - `FOLDER_MAP.md` - خريطة الملفات
   - `API_ROUTES.md` - جميع API Routes
   - `DB_SCHEMA.md` - قاعدة البيانات

2. ✅ إضافة OpenAI SDK إلى Backend (`backend/package.json`)

3. ✅ إنشاء Backend Routes و Controller:
   - `backend/routes/aiRoutes.js`
   - `backend/controllers/aiController.js`
   - تحديث `backend/server.js`

4. ✅ إنشاء Setup Script:
   - `backend/scripts/setup-vector-store.js`

5. ✅ إنشاء Flutter UI:
   - `flutter_application_1/lib/services/ai_service.dart`
   - `flutter_application_1/lib/screens/ai_assistant_screen.dart`
   - تحديث `flutter_application_1/lib/widgets/floating_smart_button.dart`

---

## 📋 الخطوات المطلوبة (التنفيذ)

### الخطوة 1: الحصول على OpenAI API Key

1. اذهب إلى https://platform.openai.com/
2. سجل الدخول أو أنشئ حساب
3. اذهب إلى **API Keys** → **Create new secret key**
4. انسخ الـ API Key (سيظهر مرة واحدة فقط!)

---

### الخطوة 2: إعداد Backend

#### 2.1 تثبيت المكتبات

```bash
cd backend
npm install
```

سيتم تثبيت `openai` تلقائياً.

#### 2.2 إضافة API Key إلى .env

افتح `backend/.env` وأضف:

```env
OPENAI_API_KEY=sk-your-api-key-here
```

⚠️ **مهم**: لا ترفع ملف `.env` على GitHub!

---

### الخطوة 3: تشغيل Setup Script (مرة واحدة)

هذا السكربت سيقوم بـ:
1. رفع ملفات `ai_knowledge/` إلى OpenAI
2. إنشاء Vector Store
3. حفظ Vector Store ID في `.env`

```bash
cd backend
node scripts/setup-vector-store.js
```

بعد انتهاء السكربت، سيتم إضافة هذا السطر تلقائياً في `.env`:
```env
OPENAI_VECTOR_STORE_ID=vs_xxxxxxxxxxxxx
```

**ملاحظة**: إذا لم يضيفه تلقائياً، أضفه يدوياً في `.env`.

---

### الخطوة 4: تشغيل Backend

```bash
cd backend
npm start
```

تحقق من أن السيرفر يعمل:
```bash
curl http://localhost:3000/api/ai/health
```

---

### الخطوة 5: تشغيل Flutter

```bash
cd flutter_application_1
flutter pub get
flutter run
```

---

## 🎯 طريقة الاستخدام

1. **افتح التطبيق Flutter**
2. **اضغط على زر "AI Assistant"** (الزر العائم في الصفحة الرئيسية)
3. **اكتب سؤالك** أو اختر أحد الخيارات السريعة
4. **الـ AI سيجيب** بناءً على ملفات المشروع!

---

## 📝 أمثلة على الأسئلة

- "حلل بنية مشروع SHAQATI"
- "اشرح نظام العقود"
- "كيف يعمل نظام الدفعات؟"
- "ما هي الأدوار في النظام؟"
- "أين يوجد كود إدارة العقارات؟"
- "ما هي نماذج قاعدة البيانات؟"

---

## 🔍 API Endpoints

### POST `/api/ai/chat`
محادثة مع AI
```json
{
  "question": "سؤالك هنا"
}
```

**Response:**
```json
{
  "success": true,
  "response": "إجابة AI...",
  "model": "gpt-4o",
  "usage": {...}
}
```

### GET `/api/ai/health`
فحص حالة AI Service
```json
{
  "success": true,
  "health": {
    "apiKeyConfigured": true,
    "vectorStoreConfigured": true,
    "vectorStoreId": "vs_xxxxx",
    "status": "ready"
  }
}
```

---

## ⚠️ ملاحظات مهمة

1. **API Key**: يجب أن يكون آمن ولا يُرفع على Git
2. **التكلفة**: استخدام OpenAI API يتطلب رصيد (بضعة دولارات تكفي للبدء)
3. **Vector Store**: يتم إنشاؤه مرة واحدة فقط. إذا أردت تحديث الملفات، يمكنك تشغيل Setup Script مرة أخرى
4. **Authentication**: جميع طلبات `/api/ai/chat` تحتاج تسجيل دخول (JWT Token)

---

## 🐛 استكشاف الأخطاء

### خطأ: "OPENAI_API_KEY غير موجود"
- تأكد من وجود `OPENAI_API_KEY` في `backend/.env`

### خطأ: "Vector Store غير موجود"
- شغّل `setup-vector-store.js` مرة أخرى
- تأكد من وجود `OPENAI_VECTOR_STORE_ID` في `.env`

### خطأ: "يجب تسجيل الدخول"
- تأكد من تسجيل الدخول في التطبيق
- الـ Token يجب أن يكون صالح

### AI لا يجيب
- تحقق من `http://localhost:3000/api/ai/health`
- تأكد من وجود رصيد في OpenAI Account

---

## 📚 الملفات المهمة

### Backend
- `backend/routes/aiRoutes.js` - Routes
- `backend/controllers/aiController.js` - Logic
- `backend/scripts/setup-vector-store.js` - Setup
- `ai_knowledge/` - ملفات المعرفة

### Flutter
- `flutter_application_1/lib/services/ai_service.dart` - API Service
- `flutter_application_1/lib/screens/ai_assistant_screen.dart` - UI
- `flutter_application_1/lib/widgets/floating_smart_button.dart` - Button

---

## 🎉 كل شيء جاهز!

بعد اتباع الخطوات أعلاه، سيكون AI Assistant جاهزاً للاستخدام!

إذا واجهت أي مشاكل، راجع قسم "استكشاف الأخطاء" أعلاه.

---

**تم إنشاء هذا النظام بواسطة:** AI Assistant  
**التاريخ:** 2025