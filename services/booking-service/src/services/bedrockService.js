const { BedrockRuntimeClient, ConverseCommand } = require("@aws-sdk/client-bedrock-runtime");

const BEDROCK_REGION = process.env.BEDROCK_REGION || process.env.AWS_REGION || "us-east-1";
const BEDROCK_MODEL_ID = process.env.BEDROCK_MODEL_ID || "amazon.nova-pro-v1:0";

const client = new BedrockRuntimeClient({ region: BEDROCK_REGION });

const isBedrockEnabled = () => Boolean(BEDROCK_MODEL_ID);

const getResponseText = (response) =>
  response?.output?.message?.content
    ?.map((part) => part.text || "")
    .join("")
    .trim() || "";

const parseJsonText = (text) => {
  if (!text) {
    throw new Error("Bedrock returned an empty response");
  }

  const cleaned = text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();

  const firstBrace = cleaned.indexOf("{");
  const firstBracket = cleaned.indexOf("[");
  const startsAt =
    firstBrace === -1 ? firstBracket : firstBracket === -1 ? firstBrace : Math.min(firstBrace, firstBracket);

  if (startsAt < 0) {
    throw new Error("Bedrock response did not contain JSON");
  }

  return JSON.parse(cleaned.slice(startsAt));
};

const generateText = async ({ prompt, temperature = 0.25, maxTokens = 1200 }) => {
  if (!isBedrockEnabled()) {
    return null;
  }

  const response = await client.send(
    new ConverseCommand({
      modelId: BEDROCK_MODEL_ID,
      messages: [
        {
          role: "user",
          content: [{ text: prompt }],
        },
      ],
      inferenceConfig: {
        maxTokens,
        temperature,
      },
    })
  );

  return getResponseText(response);
};

const generateJson = async ({ prompt, temperature = 0.2, maxTokens = 1200 }) =>
  parseJsonText(await generateText({ prompt, temperature, maxTokens }));

module.exports = {
  BEDROCK_MODEL_ID,
  BEDROCK_REGION,
  generateJson,
  generateText,
  isBedrockEnabled,
};
