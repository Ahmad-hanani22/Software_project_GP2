# 🆓 إعداد Google Gemini API - مجاني لحد 60 requests/minute

## 📋 نظرة عامة

نظام AI في SHAQATI يستخدم **Google Gemini API** - مجاني لحد 60 requests/minute، مما يجعله خياراً ممتازاً للمشاريع.

## 🎯 المزايا

- ✅ **مجاني لحد 60 requests/minute**
- ✅ **جودة عالية** - من Google
- ✅ **سريع** - استجابة فورية
- ✅ **يدعم العربية** بشكل ممتاز
- ✅ **سهل الإعداد** - فقط API Key

## 🛠️ خطوات الإعداد

### 1️⃣ الحصول على Gemini API Key

1. اذهب إلى: https://aistudio.google.com/app/apikey
2. سجل الدخول بحساب Google
3. اضغط على **"Create API Key"**
4. اختر مشروع موجود أو أنشئ مشروع جديد
5. انسخ الـ API Key (سيظهر مرة واحدة فقط!)

---

### 2️⃣ إعداد Backend

#### 2.1 تثبيت المكتبات

```bash
cd backend
npm install
```

سيتم تثبيت `@google/generative-ai` تلقائياً.

#### 2.2 إضافة API Key إلى .env

افتح ملف `backend/.env` وأضف:

```env
# Google Gemini API
GEMINI_API_KEY=your-gemini-api-key-here
GEMINI_MODEL=gemini-1.5-flash
```

**نماذج Gemini المتاحة:**
- `gemini-1.5-flash` - سريع وخفيف (موصى به - الافتراضي)
- `gemini-pro` - جودة عالية
- `gemini-1.5-pro` - أحدث وأفضل

---

### 3️⃣ تشغيل Backend

```bash
cd backend
npm start
```

أو للتطوير:

```bash
npm run dev
```

---

## ✅ اختبار النظام

### 1️⃣ فحص حالة Gemini

```bash
# من Terminal
curl http://localhost:3000/api/ai/health
```

يجب أن ترى:

```json
{
  "success": true,
  "health": {
    "available": true,
    "provider": "Google Gemini",
    "targetModel": "gemini-1.5-flash",
    "status": "ready"
  },
  "message": "AI Service جاهز للاستخدام (Google Gemini) مع ملفات المعرفة"
}
```

### 2️⃣ اختبار AI Assistant

1. شغّل Backend (إذا لم يكن يعمل)
2. افتح Flutter App
3. اذهب إلى AI Assistant
4. اسأل سؤال مثل: "ما هي ميزات مشروع SHAQATI؟"

---

## 🚀 الموديلات المتاحة

| الموديل | الوصف | الاستخدام | الحالة |
|---------|-------|-----------|--------|
| `gemini-1.5-flash` | سريع وخفيف | **موصى به للبداية** (الافتراضي) | ✅ متاح |
| `gemini-1.5-pro` | جودة عالية | للمهام المعقدة | ✅ متاح |
| `gemini-1.5-pro-latest` | أحدث إصدار | للمهام المتقدمة | ✅ متاح |
| `gemini-pro` | ❌ غير متاح | - | ❌ غير مدعوم في v1beta |

**⚠️ مهم:** `gemini-pro` غير متاح حالياً في Gemini API v1beta. استخدم `gemini-1.5-flash` أو `gemini-1.5-pro`.

للتغيير بين الموديلات، عدّل `GEMINI_MODEL` في `.env`:

```env
GEMINI_MODEL=gemini-1.5-pro  # للموديل الأحدث
```

---

## 🔧 استكشاف الأخطاء

### ❌ خطأ: "GEMINI_API_KEY is not set"

**الحل:**
1. تأكد أنك أضفت `GEMINI_API_KEY` في ملف `backend/.env`
2. تأكد أن المفتاح صحيح
3. أعد تشغيل السيرفر

---

### ❌ خطأ: "تم تجاوز الحد المسموح" (429)

**الحل:**
- Gemini مجاني لحد **60 requests/minute**
- انتظر دقيقة واحدة ثم جرب مرة أخرى
- الحد مجاني ومتاح دائماً، فقط انتظر قليلاً

---

### ❌ خطأ: "Invalid API key"

**الحل:**
1. تحقق من أن API Key صحيح (نسخ كامل)
2. احصل على API Key جديد من: https://aistudio.google.com/app/apikey
3. تأكد أن الـ API Key ليس محذوفاً أو معطلاً
4. أعد تشغيل السيرفر بعد التغيير

---

### ❌ خطأ: "Failed to connect to Gemini API"

**الحل:**
1. تحقق من اتصالك بالإنترنت
2. تأكد أن API Key صحيح
3. تحقق من أن Gemini API متاح في منطقتك

---

## 📊 حدود الاستخدام

| البند | القيمة |
|-------|--------|
| **الحد المجاني** | 60 requests/minute |
| **الحد اليومي** | ~86,400 requests (عند استخدام الحد الكامل) |
| **التكلفة بعد الحد** | حسب خطة Google |

---

## 📝 ملاحظات مهمة

- ✅ **مجاني لحد 60 requests/minute** - ممتاز للمشاريع الصغيرة والمتوسطة
- ✅ **لا يحتاج تثبيت محلي** - يعمل عبر API
- ✅ **خصوصية جيدة** - البيانات تُرسل لـ Google
- ⚠️ **يحتاج إنترنت** - لا يعمل offline
- ⚠️ **حد الاستخدام** - 60 requests/minute (مجاني)

---

## 🚀 جاهز!

الآن نظام AI يعمل مع Google Gemini API! 🎉

**الخطوات التالية:**
1. ✅ تأكد أن API Key موجود في `.env`
2. ✅ شغّل Backend
3. ✅ اختبر AI Assistant من Flutter App

---

## 📖 للمزيد من المعلومات

- [Google AI Studio](https://aistudio.google.com/)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [Gemini Models](https://ai.google.dev/models/gemini)

---

## 💡 نصائح

1. **للمشاريع الصغيرة:** استخدم `gemini-1.5-flash` (الافتراضي) - سريع ومجاني
2. **للمهام المعقدة:** استخدم `gemini-1.5-pro` - أفضل جودة
3. **للمشاريع الكبيرة:** فكر في خطة Google Cloud للحدود الأعلى

---

## 🔒 الأمان

- ✅ لا ترفع ملف `.env` على GitHub
- ✅ احفظ API Key بشكل آمن
- ✅ لا تشارك API Key مع أحد
