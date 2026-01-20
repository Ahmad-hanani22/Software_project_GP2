// utils/aiProviders.js
import OpenAI from "openai";

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function getAIProvider() {
  return {
    type: "openai",
    model: process.env.OPENAI_MODEL || "gpt-4.1",
    apiKey: process.env.OPENAI_API_KEY,
  };
}

export async function chatWithAIProvider(messages, options = {}) {
  const { temperature = 0.3, max_tokens = 400 } = options;

  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY is not set");
  }

  const client = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  const maxRetries = 3;
  let lastError;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await client.chat.completions.create({
        model: process.env.OPENAI_MODEL || "gpt-4.1",
        messages,
        temperature,
        max_tokens,
      });

      return (
        response.choices?.[0]?.message?.content ||
        "لم يتم توليد رد من OpenAI"
      );
    } catch (error) {
      lastError = error;

      if (error.status === 429) {
        const waitTime = Math.pow(2, attempt) * 1000;
        console.warn(
          `⚠️ Rate Limit - محاولة ${attempt + 1}/${maxRetries} بعد ${
            waitTime / 1000
          } ثانية...`
        );
        await sleep(waitTime);
        continue;
      }

      break;
    }
  }

  if (lastError?.status === 401 || lastError?.status === 403) {
    throw new Error("مفتاح OpenAI API غير صحيح أو غير مفعل");
  }

  if (lastError?.status === 429) {
    throw new Error("تم تجاوز حد الطلبات. انتظر دقيقة وجرب مرة ثانية");
  }

  throw new Error(`فشل الاتصال بـ OpenAI: ${lastError?.message}`);
}

export async function checkAIProviderHealth() {
  try {
    // التحقق من وجود المفتاح
    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey || apiKey === "") {
      return {
        available: false,
        error: "OPENAI_API_KEY is not set in .env file. Add: OPENAI_API_KEY=sk-proj-...",
        provider: "OpenAI",
        help: "أضف OPENAI_API_KEY في ملف backend/.env. احصل على المفتاح من: https://platform.openai.com/api-keys",
      };
    }

    // التحقق من صحة المفتاح (يجب أن يبدأ بـ sk-)
    if (!apiKey.startsWith("sk-")) {
      return {
        available: false,
        error: "OPENAI_API_KEY format is incorrect. Should start with 'sk-'",
        provider: "OpenAI",
        help: "المفتاح يجب أن يبدأ بـ 'sk-'. تحقق من المفتاح في ملف .env",
      };
    }

    const client = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    await client.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4.1",
      messages: [{ role: "user", content: "hi" }],
      max_tokens: 1,
    });

    return {
      available: true,
      provider: "OpenAI",
      model: process.env.OPENAI_MODEL || "gpt-4.1",
      status: "ready",
    };
  } catch (error) {
    let errorMessage = error.message || "Unknown error";

    if (error.status === 401 || error.status === 403) {
      errorMessage = "مفتاح OpenAI غير صحيح أو غير مفعل";
    } else if (error.status === 429) {
      errorMessage = "تم تجاوز حد الطلبات مؤقتًا، انتظر دقيقة وجرب مرة ثانية";
    }

    return {
      available: false,
      provider: "OpenAI",
      status: "not_configured",
      error: errorMessage,
    };
  }
}
