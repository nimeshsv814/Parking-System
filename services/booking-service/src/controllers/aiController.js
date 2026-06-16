const Booking = require("../models/Booking");
const { internalHeaders, parkingClient } = require("../config/http");
const {
  getGeminiDemandPrediction,
  getGeminiPaymentRisk,
  getGeminiSlotRecommendation,
} = require("../services/geminiAiService");

const getSlots = async () => {
  const response = await parkingClient.get("/internal/slots", { headers: internalHeaders() });
  return response.data || [];
};

const getRecommendation = async (req, res) => {
  try {
    const [slots, bookings] = await Promise.all([getSlots(), Booking.listBookings({ isAdmin: true })]);
    const recommendation = await getGeminiSlotRecommendation({
      slots,
      bookings,
      userId: req.user.id,
      durationHours: Number(req.query.durationHours || req.query.duration || 1),
    });

    return res.json(recommendation);
  } catch (error) {
    return res.status(500).json({ message: "Failed to recommend slot", error: error.message });
  }
};

const getDemandPrediction = async (req, res) => {
  try {
    const [slots, bookings] = await Promise.all([getSlots(), Booking.listBookings({ isAdmin: true })]);
    const predictions = await getGeminiDemandPrediction({
      slots,
      bookings,
      hours: Number(req.query.hours || 6),
    });

    return res.json(predictions);
  } catch (error) {
    return res.status(500).json({ message: "Failed to predict demand", error: error.message });
  }
};

const getPaymentRisk = async (req, res) => {
  try {
    const booking = await Booking.getBooking(req.params.bookingId);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }
    if (req.user.role !== "admin" && booking.userId !== req.user.id) {
      return res.status(403).json({ message: "Access denied" });
    }

    const bookings = await Booking.listBookings({ isAdmin: true });
    return res.json(
      await getGeminiPaymentRisk({
        booking,
        bookings,
        holdMinutes: Number(process.env.BOOKING_HOLD_MINUTES || 10),
      })
    );
  } catch (error) {
    return res.status(500).json({ message: "Failed to predict payment risk", error: error.message });
  }
};

module.exports = {
  getDemandPrediction,
  getPaymentRisk,
  getRecommendation,
};
