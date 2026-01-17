// utils/localAI.js
import fetch from "node-fetch";

const OLLAMA_BASE_URL = process.env.OLLAMA_BASE_URL || "http://localhost:11434";
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || "llama2"; // أو mistral, mixtral

/**
 * التحقق من أن Ollama يعمل
 */
export async function checkOllamaHealth() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(`${OLLAMA_BASE_URL}/api/tags`, {
      method: "GET",
      signal: controller.signal,
    });
    
    clearTimeout(timeoutId);

    if (response.ok) {
      const data = await response.json();
      const models = data.models || [];
      const hasModel = models.some((m) => m.name.includes(OLLAMA_MODEL));
      
      return {
        available: true,
        models: models.map((m) => m.name),
        targetModel: OLLAMA_MODEL,
        hasTargetModel: hasModel,
      };
    }
    
    return { 
      available: false, 
      error: `Ollama server responded with status ${response.status}` 
    };
  } catch (error) {
    if (error.name === 'AbortError') {
      return {
        available: false,
        error: "Connection timeout - Ollama may not be running",
      };
    }
    
    if (error.code === 'ECONNREFUSED' || error.message?.includes('ECONNREFUSED')) {
      return {
        available: false,
        error: "Ollama is not running. Please start it with: ollama serve",
      };
    }
    
    return {
      available: false,
      error: error.message || "Cannot connect to Ollama server",
    };
  }
}

/**
 * إرسال سؤال إلى Ollama
 */
export async function askOllama(prompt, options = {}) {
  const {
    model = OLLAMA_MODEL,
    temperature = 0.7,
    max_tokens = 2000,
    stream = false,
  } = options;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 120000); // 2 minutes
    
    const response = await fetch(`${OLLAMA_BASE_URL}/api/generate`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: model,
        prompt: prompt,
        stream: stream,
        options: {
          temperature: Math.min(temperature || 0.3, 0.5), // Cap at 0.5 for faster, focused responses
          num_predict: Math.min(max_tokens || 800, 1000), // Cap at 1000 tokens for speed
          top_p: 0.8,
          top_k: 30,
        },
      }),
      signal: controller.signal,
    });
    
    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(
        `Ollama API error (${response.status}): ${errorText}`
      );
    }

    const data = await response.json();
    return data.response || "";
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error("Request timeout - The model may be too large or slow");
    }
    
    if (error.code === 'ECONNREFUSED' || error.message?.includes('ECONNREFUSED')) {
      throw new Error("Ollama is not running. Please start it with: ollama serve");
    }
    
    console.error("❌ Ollama API Error:", error);
    throw error;
  }
}

/**
 * إرسال محادثة (Chat) إلى Ollama
 * Ollama يدعم Chat API بشكل أفضل من Generate
 */
export async function chatWithOllama(messages, options = {}) {
  const {
    model = OLLAMA_MODEL,
    temperature = 0.7,
    max_tokens = 2000,
  } = options;

  try {
    // تحويل messages إلى format Ollama
    const formattedMessages = messages.map((msg) => ({
      role: msg.role === "system" ? "system" : msg.role,
      content: msg.content,
    }));

    // ✅ تعريف controller للـ timeout (45 ثانية - محسّن للسرعة)
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 45000); // 45 seconds

    const response = await fetch(`${OLLAMA_BASE_URL}/api/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: model,
        messages: formattedMessages,
        stream: false,
        options: {
          temperature: Math.min(temperature || 0.3, 0.5), // Cap at 0.5 for faster, focused responses
          num_predict: Math.min(max_tokens || 800, 1000), // Cap at 1000 tokens for speed
          top_p: 0.8,
          top_k: 30,
        },
      }),
      signal: controller.signal,
    });
    
    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(
        `Ollama API error (${response.status}): ${errorText}`
      );
    }

    const data = await response.json();
    return data.message?.content || data.response || "";
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error("انتهت مهلة الاتصال - الموديل قد يكون كبيراً أو بطيئاً. جرب موديل أصغر مثل llama2");
    }
    
    if (error.code === 'ECONNREFUSED' || error.message?.includes('ECONNREFUSED')) {
      throw new Error("Ollama is not running. Please start it with: ollama serve");
    }
    
    console.error("❌ Ollama Chat API Error:", error);
    throw error;
  }
}

/**
 * تحميل موديل إذا لم يكن موجوداً
 */
export async function pullModel(modelName = OLLAMA_MODEL) {
  try {
    console.log(`📥 جاري تحميل الموديل ${modelName}...`);
    
    const response = await fetch(`${OLLAMA_BASE_URL}/api/pull`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name: modelName,
        stream: false,
      }),
      timeout: 600000, // 10 minutes for model download
    });

    if (!response.ok) {
      throw new Error(`Failed to pull model: ${response.statusText}`);
    }

    const data = await response.json();
    console.log(`✅ تم تحميل الموديل ${modelName} بنجاح`);
    return data;
  } catch (error) {
    console.error(`❌ خطأ في تحميل الموديل ${modelName}:`, error);
    throw error;
  }
}
