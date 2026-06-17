const { recommendSlot } = require("./aiRecommendationService");
const { generateJson, isGeminiEnabled } = require("./geminiService");

const VEHICLE_TYPES = [
  { id: "two-wheeler", label: "Two-wheeler" },
  { id: "four-wheeler", label: "Four-wheeler" },
];

const normalizeLocation = (location) => String(location || "General").trim() || "General";

const slotSupportsVehicle = (slot, vehicleType) => {
  const text = `${slot.slotId || ""} ${slot.location || ""}`.toLowerCase();
  const explicitlyTwoWheeler = /(two|2)[-\s]?wheeler|bike|scooter|motorcycle/.test(text);
  const explicitlyFourWheeler = /(four|4)[-\s]?wheeler|car|suv/.test(text);

  if (vehicleType === "two-wheeler") {
    return !explicitlyFourWheeler || explicitlyTwoWheeler;
  }
  if (vehicleType === "four-wheeler") {
    return !explicitlyTwoWheeler || explicitlyFourWheeler;
  }
  return true;
};

const getLocationDemand = ({ location, slots, bookings }) => {
  const locationSlots = slots.filter((slot) => normalizeLocation(slot.location) === location);
  const slotIds = new Set(locationSlots.map((slot) => slot.slotId));
  const availableSlots = locationSlots.filter((slot) => slot.status === "available").length;
  const activeSlots = locationSlots.filter((slot) => ["reserved", "occupied"].includes(slot.status)).length;
  const historicalBookings = bookings.filter((booking) => slotIds.has(booking.slotId)).length;

  const activePressure = locationSlots.length > 0 ? activeSlots / locationSlots.length : 1;
  const historyPressure = Math.min(1, historicalBookings / Math.max(1, bookings.length || 1));
  const demandScore = Number((activePressure * 0.65 + historyPressure * 0.35).toFixed(2));

  let demandLevel = "LOW";
  if (demandScore >= 0.66) {
    demandLevel = "HIGH";
  } else if (demandScore >= 0.34) {
    demandLevel = "MEDIUM";
  }

  return {
    location,
    availableSlots,
    totalSlots: locationSlots.length,
    demandLevel,
    demandScore,
    reason:
      demandLevel === "LOW"
        ? `${location} has open slots and lower recent booking pressure.`
        : `${location} has ${demandLevel.toLowerCase()} demand based on active and historical bookings.`,
  };
};

const getAssistantOptions = ({ slots, bookings, vehicleType }) => {
  const compatibleSlots = slots.filter((slot) => slotSupportsVehicle(slot, vehicleType));
  const locations = Array.from(new Set(compatibleSlots.map((slot) => normalizeLocation(slot.location))))
    .map((location) => getLocationDemand({ location, slots: compatibleSlots, bookings }))
    .filter((item) => item.totalSlots > 0)
    .sort(
      (left, right) =>
        left.demandScore - right.demandScore ||
        right.availableSlots - left.availableSlots ||
        left.location.localeCompare(right.location)
    );

  return {
    vehicleTypes: VEHICLE_TYPES,
    selectedVehicleType: vehicleType || null,
    locations,
    suggestedLocation: locations.find((item) => item.availableSlots > 0) || locations[0] || null,
    message: vehicleType
      ? "I checked current availability and past booking demand. These locations are sorted from lowest demand to highest."
      : "I can help you find a low-demand slot. Choose your vehicle type first.",
  };
};

const getAssistantRecommendation = ({ slots, bookings, userId, vehicleType, location, durationHours }) => {
  const compatibleSlots = slots.filter(
    (slot) => slotSupportsVehicle(slot, vehicleType) && normalizeLocation(slot.location) === normalizeLocation(location)
  );
  const locationDemand = getLocationDemand({
    location: normalizeLocation(location),
    slots: compatibleSlots,
    bookings,
  });
  const recommendation = recommendSlot({
    slots: compatibleSlots,
    bookings,
    userId,
    durationHours,
  });

  return {
    vehicleType,
    location: normalizeLocation(location),
    demandLevel: locationDemand.demandLevel,
    recommendedSlotId: recommendation.recommendedSlotId,
    reason: recommendation.recommendedSlotId
      ? `${recommendation.reason} ${locationDemand.reason}`
      : `No available ${vehicleType || "vehicle"} slot is available in ${normalizeLocation(location)} right now.`,
    score: recommendation.score,
    nextStep: recommendation.recommendedSlotId ? "PROCEED_TO_PAYMENT" : "TRY_ANOTHER_LOCATION",
    paymentPrompt: recommendation.recommendedSlotId
      ? `I found slot ${recommendation.recommendedSlotId}. Shall I reserve it and take you to payment?`
      : "Please choose another location with available slots.",
  };
};

const assistantChatSchema = {
  type: "OBJECT",
  properties: {
    reply: { type: "STRING" },
    vehicleType: { type: "STRING" },
    durationHours: { type: "NUMBER" },
    preferredLocation: { type: "STRING" },
    recommendedSlotId: { type: "STRING" },
    reason: { type: "STRING" },
    confidence: { type: "NUMBER" },
    nextAction: { type: "STRING" },
  },
  required: ["reply", "vehicleType", "durationHours", "recommendedSlotId", "reason", "confidence", "nextAction"],
};

const compactSlotsForRetrieval = (slots) =>
  slots.map((slot) => ({
    slotId: slot.slotId,
    location: slot.location,
    status: slot.status,
    price: Number(slot.price) || 0,
  }));

const compactBookingsForRetrieval = (bookings, limit = 100) =>
  bookings.slice(0, limit).map((booking) => ({
    slotId: booking.slotId,
    status: booking.status,
    vehicleType: booking.vehicleType,
    durationHours: Number(booking.durationHours) || 1,
    amount: Number(booking.amount) || 0,
    createdAt: booking.createdAt || booking.timestamp,
    paidAt: booking.paidAt,
    expiresAt: booking.expiresAt,
  }));

const inferVehicleType = (message, fallback = "four-wheeler") => {
  const text = String(message || "").toLowerCase();
  if (/two|2|bike|scooter|motorcycle/.test(text)) {
    return "two-wheeler";
  }
  if (/four|4|car|suv/.test(text)) {
    return "four-wheeler";
  }
  return fallback;
};

const inferDurationHours = (message, fallback = 1) => {
  const match = String(message || "").match(/(\d+(?:\.\d+)?)\s*(?:hour|hr|hrs|h)\b/i);
  if (!match) {
    return fallback;
  }
  return Math.min(24, Math.max(1, Math.ceil(Number(match[1]) || fallback)));
};

const getFallbackAssistantChat = ({ message, slots, bookings, userId }) => {
  const vehicleType = inferVehicleType(message);
  const durationHours = inferDurationHours(message);
  const options = getAssistantOptions({ slots, bookings, vehicleType });
  const location = options.suggestedLocation?.location || normalizeLocation(slots[0]?.location);
  const recommendation = getAssistantRecommendation({
    slots,
    bookings,
    userId,
    vehicleType,
    location,
    durationHours,
  });

  return {
    reply: recommendation.recommendedSlotId
      ? `I found ${recommendation.recommendedSlotId} for your ${vehicleType.replace("-", " ")} for ${durationHours} hour(s). ${recommendation.reason}`
      : `I could not find an available ${vehicleType.replace("-", " ")} slot for that request right now.`,
    vehicleType,
    durationHours,
    preferredLocation: location,
    recommendedSlotId: recommendation.recommendedSlotId,
    reason: recommendation.reason,
    confidence: recommendation.score,
    nextAction: recommendation.nextStep,
    aiProvider: "LOCAL_FALLBACK",
    retrievedContext: {
      availableSlots: slots.filter((slot) => slot.status === "available").length,
      bookingHistoryRecords: bookings.length,
      locationDemand: options.locations.slice(0, 5),
    },
  };
};

const getAssistantChatResponse = async ({ message, slots, bookings, userId }) => {
  const fallback = getFallbackAssistantChat({ message, slots, bookings, userId });

  if (!isGeminiEnabled()) {
    return fallback;
  }

  try {
    const result = await generateJson({
      schema: assistantChatSchema,
      temperature: 0.25,
      prompt: `You are QuickSlot AI, an LLM parking assistant inside a Smart Parking System.
This is a RAG-style task: use only the retrieved live application context below, not generic assumptions.
Understand the user's natural language request, infer vehicle type and duration when possible, compare available slots, historical booking pressure, current demand, price, and location.
Recommend one currently available slot if possible. If details are missing, still make a reasonable recommendation using defaults.
Return only JSON matching this schema:
{"reply":"string","vehicleType":"two-wheeler|four-wheeler","durationHours":1,"preferredLocation":"string","recommendedSlotId":"string|null","reason":"string","confidence":0.0,"nextAction":"ASK_DETAILS|SUGGEST_SLOT|PROCEED_TO_PAYMENT|NO_SLOT_AVAILABLE"}

User message:
${message}

User:
${JSON.stringify({ userId, now: new Date().toISOString() })}

Retrieved live slots:
${JSON.stringify(compactSlotsForRetrieval(slots))}

Retrieved booking history:
${JSON.stringify(compactBookingsForRetrieval(bookings))}

Local fallback recommendation:
${JSON.stringify(fallback)}`,
    });

    const availableSlotIds = new Set(slots.filter((slot) => slot.status === "available").map((slot) => slot.slotId));
    const recommendedSlotId = availableSlotIds.has(result.recommendedSlotId) ? result.recommendedSlotId : fallback.recommendedSlotId;
    const confidence = Math.min(1, Math.max(0, Number(result.confidence) || fallback.confidence || 0));

    return {
      ...fallback,
      ...result,
      recommendedSlotId,
      confidence,
      aiProvider: "GEMINI",
      retrievedContext: fallback.retrievedContext,
    };
  } catch (error) {
    console.error("Gemini assistant chat fallback used:", error.response?.data || error.message);
    return { ...fallback, aiError: "Gemini unavailable or returned invalid JSON" };
  }
};

module.exports = {
  getAssistantChatResponse,
  getAssistantOptions,
  getAssistantRecommendation,
};
