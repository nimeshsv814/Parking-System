const { recommendSlot } = require("./aiRecommendationService");

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

module.exports = {
  getAssistantOptions,
  getAssistantRecommendation,
};
