const { getHour, parseDate } = require("./aiUtils");

const getDemandLevel = (booked, totalSlots) => {
  const ratio = totalSlots > 0 ? booked / totalSlots : 0;
  if (ratio >= 0.65) {
    return "HIGH";
  }
  if (ratio >= 0.35) {
    return "MEDIUM";
  }
  return "LOW";
};

const countActiveBookingsForHour = (bookings, hour) =>
  bookings.filter((booking) => {
    if (!["pending", "confirmed"].includes(booking.status)) {
      return false;
    }
    const createdHour = getHour(booking.createdAt || booking.timestamp);
    return createdHour === hour;
  }).length;

const averageHistoricalBookingsForHour = (bookings, hour) => {
  const historicalBookings = bookings.filter((booking) => {
    const date = parseDate(booking.createdAt || booking.timestamp);
    return date && getHour(date) === hour && ["confirmed", "expired", "cancelled"].includes(booking.status);
  });

  const days = new Set(
    historicalBookings.map((booking) => parseDate(booking.createdAt || booking.timestamp).toISOString().slice(0, 10))
  );

  if (historicalBookings.length < 5 || days.size < 2) {
    return null;
  }

  return historicalBookings.length / days.size;
};

const predictDemand = ({ bookings, totalSlots, hours = 6, now = new Date() }) => {
  const predictions = [];
  const currentHour = now.getHours();

  for (let offset = 0; offset < hours; offset += 1) {
    const target = new Date(now);
    target.setHours(currentHour + offset, 0, 0, 0);
    const hour = target.getHours();
    const historicalAverage = averageHistoricalBookingsForHour(bookings, hour);
    const activeNow = offset === 0 ? countActiveBookingsForHour(bookings, hour) : 0;
    const peakBoost = (hour >= 8 && hour <= 11) || (hour >= 17 && hour <= 21) ? 1.2 : 1;
    const fallbackBase = totalSlots * (((hour >= 8 && hour <= 11) || (hour >= 17 && hour <= 21)) ? 0.55 : 0.25);
    const predictedBookedSlots = Math.min(
      totalSlots,
      Math.round(Math.max(activeNow, (historicalAverage ?? fallbackBase) * peakBoost))
    );

    predictions.push({
      time: target.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", hour12: false }),
      predictedBookedSlots,
      predictedAvailableSlots: Math.max(0, totalSlots - predictedBookedSlots),
      demandLevel: getDemandLevel(predictedBookedSlots, totalSlots),
      basis: historicalAverage === null ? "fallback_peak_hour_average" : "historical_hourly_average",
    });
  }

  return predictions;
};

module.exports = {
  predictDemand,
};
