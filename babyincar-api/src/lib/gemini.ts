/**
 * Gemini API adapter — lightweight REST wrapper, no npm packages needed.
 * Uses Gemini 2.0 Flash (free tier).
 */

const GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

/** Daily quota cap — leaves 300 buffer for live traffic on the 1500 free-tier limit. */
const DAILY_QUOTA_LIMIT = 1200;

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{ text?: string }>;
    };
  }>;
  promptFeedback?: { blockReason?: string };
  error?: { message: string };
}

/**
 * Increment and check the daily Gemini call counter in KV.
 * Returns true if under quota, false if exceeded.
 */
export async function checkGeminiQuota(kv: KVNamespace): Promise<boolean> {
  const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const key = `gemini:daily:${date}`;
  const current = await kv.get(key);
  const count = current ? parseInt(current, 10) : 0;

  if (count >= DAILY_QUOTA_LIMIT) {
    return false;
  }

  await kv.put(key, (count + 1).toString(), { expirationTtl: 172800 }); // 48h TTL
  return true;
}

/**
 * Parse and validate a Gemini response, handling safety blocks and empty bodies.
 */
function extractText(data: GeminiResponse): string {
  const candidate = data.candidates?.[0];
  if (!candidate?.content?.parts?.length) {
    const reason = data.promptFeedback?.blockReason || 'empty response';
    throw new Error(`Gemini blocked: ${reason}`);
  }
  return candidate.content.parts[0]?.text ?? '';
}

/**
 * Call Gemini 2.0 Flash with a simple text prompt.
 *
 * @param kv  Optional KV namespace for daily quota tracking. When provided the
 *            call is skipped (returns empty string) if the daily cap is reached.
 */
export async function callGemini(
  apiKey: string,
  prompt: string,
  maxTokens: number = 500,
  kv?: KVNamespace,
): Promise<string> {
  if (kv && !(await checkGeminiQuota(kv))) {
    console.warn('[Gemini] Daily quota exceeded — skipping call');
    return '';
  }

  const response = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: { maxOutputTokens: maxTokens },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    const sanitized = errorBody.replace(/key=[^&\s"]+/gi, 'key=***').slice(0, 200);
    throw new Error(`Gemini API error ${response.status}: ${sanitized}`);
  }

  const data: GeminiResponse = await response.json();

  if (data.error) {
    throw new Error(`Gemini API error: ${data.error.message}`);
  }

  return extractText(data);
}

/**
 * Call Gemini with a system instruction + user message (chat-style).
 *
 * @param kv  Optional KV namespace for daily quota tracking.
 */
export async function callGeminiChat(
  apiKey: string,
  systemInstruction: string,
  userMessage: string,
  maxTokens: number = 1024,
  kv?: KVNamespace,
): Promise<string> {
  if (kv && !(await checkGeminiQuota(kv))) {
    console.warn('[Gemini] Daily quota exceeded — skipping call');
    return '';
  }

  const response = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [{ role: 'user', parts: [{ text: userMessage }] }],
      generationConfig: { maxOutputTokens: maxTokens },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    const sanitized = errorBody.replace(/key=[^&\s"]+/gi, 'key=***').slice(0, 200);
    throw new Error(`Gemini API error ${response.status}: ${sanitized}`);
  }

  const data: GeminiResponse = await response.json();

  if (data.error) {
    throw new Error(`Gemini API error: ${data.error.message}`);
  }

  return extractText(data);
}
