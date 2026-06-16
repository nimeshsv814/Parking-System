const axios = require("axios");

const GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";

const isGeminiEnabled = () => Boolean(process.env.GEMINI_API_KEY);

const getResponseText = (response) =>
  response?.data?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("")
    .trim() || "";

const parseJsonText = (text) => {
  if (!text) {
    throw new Error("Gemini returned an empty response");
  }

  const cleaned = text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();

  return JSON.parse(cleaned);
};

const generateJson = async ({ prompt, schema, temperature = 0.2 }) => {
  if (!isGeminiEnabled()) {
    return null;
  }

  const model = process.env.GEMINI_MODEL || "gemini-2.5-flash";
  const response = await axios.post(
    `${GEMINI_API_BASE_URL}/models/${model}:generateContent`,
    {
      contents: [
        {
          role: "user",
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        temperature,
        response_mime_type: "application/json",
        response_schema: schema,
      },
    },
    {
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": process.env.GEMINI_API_KEY,
      },
      timeout: Number(process.env.GEMINI_TIMEOUT_MS || 12000),
    }
  );

  return parseJsonText(getResponseText(response));
};

module.exports = {
  generateJson,
  isGeminiEnabled,
};
