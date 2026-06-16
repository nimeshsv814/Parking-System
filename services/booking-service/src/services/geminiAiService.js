const { recommendSlot } = require("./aiRecommendationService");
const { predictDemand } = require("./demandPredictionService");
const { generateJson, isGeminiEnabled } = require("./geminiService");
const { predictPaymentRisk } = require("./paymentRiskService");

const compactBookings = (bookings, limit = 80) =>
  bookings.slice(0, limit).map((booking) => ({
    bookingId: booking.bookingId,
    userId: booking.userId,
    slotId: booking.slotId,
    amount: Number(booking.amount) || 0,
    status: booking.status,
    createdAt: booking.createdAt || booking.timestamp,
    expiresAt: booking.expiresAt,
    paidAt: booking.paidAt,
  }));

const compactSlots = (slots) =>
  slots.map((slot) => ({
    slotId: slot.slotId,
    location: slot.location,
    status: slot.status,
    price: Number(slot.price) || 0,
  }));

const withFallback = async (fallback, geminiCall) => {
  if (!isGeminiEnabled()) {
    return { ...fallback, aiProvider: "LOCAL_FALLBACK" };
  }

  try {
    const result = await geminiCall();
    return { ...fallback, ...result, aiProvider: "GEMINI" };
  } catch (error) {
    console.error("Gemini AI fallback used:", error.response?.data || error.message);
    return { ...fallback, aiProvider: "LOCAL_FALLBACK", aiError: "Gemini unavailable or returned invalid JSON" };
  }
};

const normalizeScore = (score, fallbackScore) => {
  const numericScore = Number(score);
  if (!Number.isFinite(numericScore)) {
    return fallbackScore;
  }
  return Math.min(1, Math.max(0, Number(numericScore.toFixed(2))));
};

const recommendationSchema = {
  type: "OBJECT",
  properties: {
    recommendedSlotId: { type: "STRING" },
    reason: { type: "STRING" },
    score: { type: "NUMBER" },
  },
  required: ["recommendedSlotId", "reason", "score"],
};

const demandSchema = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      time: { type: "STRING" },
      predictedBookedSlots: { type: "NUMBER" },
      predictedAvailableSlots: { type: "NUMBER" },
      demandLevel: { type: "STRING" },
    },
    required: ["time", "predictedBookedSlots", "predictedAvailableSlots", "demandLevel"],
  },
};

const paymentRiskSchema = {
  type: "OBJECT",
  properties: {
    bookingId: { type: "STRING" },
    riskLevel: { type: "STRING" },
    riskScore: { type: "NUMBER" },
    action: { type: "STRING" },
  },
  required: ["bookingId", "riskLevel", "riskScore", "action"],
};

const getGeminiSlotRecommendation = async ({ slots, bookings, userId, durationHours }) => {
  const fallback = recommendSlot({ slots, bookings, userId, durationHours });
  return withFallback(fallback, async () =>
    generateJson({
      schema: recommendationSchema,
      prompt: `You are the AI decision engine for a Smart Parking System.
Recommend exactly one best available slot for the user.
Use only available slots. Consider location, floor/zone convenience, current status, historical booking frequency, peak-hour demand, requested duration, price, and pending payment risk.
Return only JSON matching this schema:
{"recommendedSlotId":"string","reason":"string","score":0.0}
Score must be between 0 and 1.

User context:
${JSON.stringify({ userId, durationHours, now: new Date().toISOString() })}

Slots:
${JSON.stringify(compactSlots(slots))}

Recent booking history:
${JSON.stringify(compactBookings(bookings))}`,
    }).then((result) => {
      const availableSlotIds = new Set(slots.filter((slot) => slot.status === "available").map((slot) => slot.slotId));
      if (!availableSlotIds.has(result.recommendedSlotId)) {
        throw new Error("Gemini recommended a slot that is not available");
      }
      return {
        recommendedSlotId: result.recommendedSlotId,
        reason: result.reason || fallback.reason,
        score: normalizeScore(result.score, fallback.score),
      };
    })
  );
};

const getGeminiDemandPrediction = async ({ slots, bookings, hours }) => {
  const fallback = predictDemand({ bookings, totalSlots: slots.length, hours });
  return withFallback({ predictions: fallback }, async () => {
    const result = await generateJson({
      schema: demandSchema,
      prompt: `You are the AI demand prediction engine for a Smart Parking System.
Predict parking demand for the next ${hours} hours.
Use historical booking times, current active bookings, total slot count, peak/off-peak patterns, and unavailable slots.
Return only a JSON array. Demand level must be LOW, MEDIUM, or HIGH.

Context:
${JSON.stringify({ now: new Date().toISOString(), totalSlots: slots.length, hours })}

Slots:
${JSON.stringify(compactSlots(slots))}

Recent booking history:
${JSON.stringify(compactBookings(bookings, 120))}`,
    });
    return {
      predictions: result.map((item, index) => ({
        time: item.time || fallback[index]?.time,
        predictedBookedSlots: Math.max(0, Math.round(Number(item.predictedBookedSlots) || 0)),
        predictedAvailableSlots: Math.max(0, Math.round(Number(item.predictedAvailableSlots) || 0)),
        demandLevel: ["LOW", "MEDIUM", "HIGH"].includes(item.demandLevel) ? item.demandLevel : "MEDIUM",
      })),
    };
  }).then((result) => result.predictions.map((item) => ({ ...item, aiProvider: result.aiProvider })));
};

const getGeminiPaymentRisk = async ({ booking, bookings, holdMinutes }) => {
  const fallback = predictPaymentRisk({ booking, bookings, holdMinutes });
  return withFallback(fallback, async () =>
    generateJson({
      schema: paymentRiskSchema,
      prompt: `You are the AI payment-risk engine for a Smart Parking System.
Predict whether this pending booking is likely to expire before payment.
Consider time since booking was created, remaining time before expiry, user's previous payment success/failure history, booking amount, and peak-hour pressure.
Return only JSON matching this schema:
{"bookingId":"string","riskLevel":"LOW|MEDIUM|HIGH","riskScore":0.0,"action":"MONITOR|SEND_PAYMENT_REMINDER"}
Risk score must be between 0 and 1.

Booking to score:
${JSON.stringify(booking)}

Hold minutes:
${holdMinutes}

User and system booking history:
${JSON.stringify(compactBookings(bookings))}`,
    }).then((result) => ({
      bookingId: booking.bookingId,
      riskLevel: ["LOW", "MEDIUM", "HIGH"].includes(result.riskLevel) ? result.riskLevel : fallback.riskLevel,
      riskScore: normalizeScore(result.riskScore, fallback.riskScore),
      action: ["MONITOR", "SEND_PAYMENT_REMINDER"].includes(result.action) ? result.action : fallback.action,
    }))
  );
};

module.exports = {
  getGeminiDemandPrediction,
  getGeminiPaymentRisk,
  getGeminiSlotRecommendation,
};
