// scripts/setup-vector-store.js
// سكربت لرفع ملفات ai_knowledge/ فقط

import "dotenv/config";
import OpenAI from "openai";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const knowledgeDir = path.join(__dirname, "../../ai_knowledge");

console.log("🚀 رفع ملفات المعرفة...\n");

// التحقق من وجود المجلد
if (!fs.existsSync(knowledgeDir)) {
  console.error(`❌ المجلد ${knowledgeDir} غير موجود`);
  process.exit(1);
}

// قراءة الملفات
const files = fs.readdirSync(knowledgeDir).filter(
  (file) => file.endsWith(".md") || file.endsWith(".txt")
);

if (files.length === 0) {
  console.error("❌ لا توجد ملفات في مجلد ai_knowledge/");
  process.exit(1);
}

console.log(`📁 وجد ${files.length} ملف(ات)\n`);

const uploadedFileIds = [];

for (const file of files) {
  try {
    const filePath = path.join(knowledgeDir, file);
    console.log(`📤 رفع: ${file}...`);

    const uploadedFile = await openai.files.create({
      file: fs.createReadStream(filePath),
      purpose: "assistants",
    });

    uploadedFileIds.push(uploadedFile.id);
    console.log(`   ✅ ${uploadedFile.id}\n`);

    // تأخير بسيط لتجنب rate limit
    await new Promise((resolve) => setTimeout(resolve, 1000));
  } catch (error) {
    console.error(`   ❌ خطأ: ${error.message}\n`);
  }
}

if (uploadedFileIds.length === 0) {
  console.error("❌ لم يتم رفع أي ملف");
  process.exit(1);
}

console.log("🎉 انتهى رفع الملفات!\n");
console.log("📌 FILE IDS:");
console.log(uploadedFileIds.join(","));
console.log("");

// محاولة حفظ في .env
const envPath = path.join(__dirname, "../.env");
if (fs.existsSync(envPath)) {
  try {
    let envContent = fs.readFileSync(envPath, "utf8");
    
    // تحديث أو إضافة OPENAI_FILE_IDS
    if (envContent.includes("OPENAI_FILE_IDS=")) {
      envContent = envContent.replace(
        /OPENAI_FILE_IDS=.*/,
        `OPENAI_FILE_IDS=${uploadedFileIds.join(",")}`
      );
    } else {
      envContent += `\nOPENAI_FILE_IDS=${uploadedFileIds.join(",")}\n`;
    }
    
    fs.writeFileSync(envPath, envContent);
    console.log("✅ تم تحديث ملف .env تلقائياً!");
    console.log(`   OPENAI_FILE_IDS=${uploadedFileIds.join(",")}\n`);
  } catch (error) {
    console.log("⚠️  لم يتم تحديث .env تلقائياً");
    console.log("💡 أضف هذا السطر يدوياً في backend/.env:\n");
    console.log(`   OPENAI_FILE_IDS=${uploadedFileIds.join(",")}\n`);
  }
} else {
  console.log("💡 أضف هذا السطر في backend/.env:\n");
  console.log(`   OPENAI_FILE_IDS=${uploadedFileIds.join(",")}\n`);
}

console.log("✅ اكتمل الإعداد!");
