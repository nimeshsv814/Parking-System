import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { aiApi, bookingApi, getApiError } from "../api/client";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../context/ToastContext";

const demandClasses = {
  LOW: "bg-mint/15 text-green-900",
  MEDIUM: "bg-amber/20 text-amber-950",
  HIGH: "bg-ember/15 text-red-900",
};

export const SmartParkingAssistant = () => {
  const { user } = useAuth();
  const { pushToast } = useToast();
  const navigate = useNavigate();
  const location = useLocation();
  const [open, setOpen] = useState(false);
  const [vehicleType, setVehicleType] = useState("");
  const [durationHours, setDurationHours] = useState(1);
  const [selectedLocation, setSelectedLocation] = useState("");
  const [options, setOptions] = useState(null);
  const [recommendation, setRecommendation] = useState(null);
  const [chatMessage, setChatMessage] = useState("I need a four-wheeler slot for 2 hours with low demand.");
  const [chatResponse, setChatResponse] = useState(null);
  const [loading, setLoading] = useState(false);
  const [booking, setBooking] = useState(false);

  const shouldAutoOpen = Boolean(user) && !location.pathname.startsWith("/payment");

  useEffect(() => {
    if (!shouldAutoOpen) {
      return;
    }

    const key = `smartParkingAssistantSeen:${user?.id || "user"}`;
    if (!sessionStorage.getItem(key)) {
      sessionStorage.setItem(key, "true");
      setOpen(true);
    }
  }, [shouldAutoOpen, user?.id]);

  useEffect(() => {
    if (!open || !vehicleType) {
      return;
    }

    const loadOptions = async () => {
      setLoading(true);
      setRecommendation(null);
      try {
        const response = await aiApi.get(`/assistant/options?vehicleType=${encodeURIComponent(vehicleType)}`);
        setOptions(response.data);
        setSelectedLocation(response.data.suggestedLocation?.location || "");
      } catch (error) {
        pushToast({ title: "Assistant unavailable", description: getApiError(error), tone: "error" });
      } finally {
        setLoading(false);
      }
    };

    loadOptions();
  }, [open, pushToast, vehicleType]);

  const locations = useMemo(() => options?.locations || [], [options]);

  const handleRecommend = async () => {
    if (!vehicleType || !selectedLocation) {
      return;
    }

    setLoading(true);
    try {
      const response = await aiApi.get(
        `/assistant/recommend?vehicleType=${encodeURIComponent(vehicleType)}&location=${encodeURIComponent(
          selectedLocation
        )}&durationHours=${encodeURIComponent(Math.min(24, Math.max(1, Number(durationHours) || 1)))}`
      );
      setRecommendation(response.data);
    } catch (error) {
      pushToast({ title: "Recommendation failed", description: getApiError(error), tone: "error" });
    } finally {
      setLoading(false);
    }
  };

  const applyAssistantResponse = (response) => {
    if (response.vehicleType) {
      setVehicleType(response.vehicleType);
    }
    if (response.durationHours) {
      setDurationHours(response.durationHours);
    }
    if (response.preferredLocation) {
      setSelectedLocation(response.preferredLocation);
    }
    setChatResponse(response);
    setRecommendation({
      recommendedSlotId: response.recommendedSlotId,
      reason: response.reason || response.reply,
      score: response.confidence,
      nextStep:
        response.recommendedSlotId && ["PROCEED_TO_PAYMENT", "SUGGEST_SLOT"].includes(response.nextAction)
          ? "PROCEED_TO_PAYMENT"
          : "TRY_ANOTHER_LOCATION",
      paymentPrompt: response.recommendedSlotId
        ? `I found slot ${response.recommendedSlotId}. Shall I reserve it and take you to payment?`
        : response.refusalReason || "I need another valid location, vehicle type, or time to find an available slot.",
    });
  };

  const handleChatSubmit = async (event) => {
    event.preventDefault();
    if (!chatMessage.trim()) {
      return;
    }

    setLoading(true);
    try {
      const response = await aiApi.post("/assistant/chat", { message: chatMessage.trim() });
      applyAssistantResponse(response.data);
    } catch (error) {
      pushToast({ title: "Assistant chat failed", description: getApiError(error), tone: "error" });
    } finally {
      setLoading(false);
    }
  };

  const handleProceedToPayment = async () => {
    if (!recommendation?.recommendedSlotId) {
      return;
    }

    setBooking(true);
    try {
      const response = await bookingApi.post("/bookings", {
        slotId: recommendation.recommendedSlotId,
        vehicleType,
        durationHours: Math.min(24, Math.max(1, Number(durationHours) || 1)),
      });
      setOpen(false);
      pushToast({
        title: "Slot reserved by AI assistant",
        description: `Booking ${response.data.booking.bookingId} is ready for payment.`,
        tone: "success",
      });
      navigate(`/payment/${response.data.booking.bookingId}`);
    } catch (error) {
      pushToast({ title: "Booking failed", description: getApiError(error), tone: "error" });
    } finally {
      setBooking(false);
    }
  };

  return (
    <>
      <button
        type="button"
        className="fixed bottom-5 right-5 z-40 rounded-full bg-ink px-5 py-3 text-sm font-semibold text-white shadow-glow transition hover:-translate-y-1"
        onClick={() => setOpen(true)}
      >
        AI Assistant
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-end bg-ink/35 px-4 py-5 backdrop-blur-sm sm:items-center sm:justify-center">
          <div className="glass-panel max-h-[88vh] w-full max-w-2xl overflow-y-auto p-5 sm:p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.24em] text-slate">AI Parking Assistant</p>
                <h2 className="mt-1 text-2xl font-semibold">Find a low-demand slot</h2>
              </div>
              <button type="button" className="button-secondary px-4 py-2" onClick={() => setOpen(false)}>
                Close
              </button>
            </div>

            <div className="mt-6 space-y-5">
              <section className="rounded-2xl border border-ink/10 bg-white/75 p-4">
                <p className="text-sm font-semibold text-ink">Ask in natural language</p>
                <form className="mt-3 space-y-3" onSubmit={handleChatSubmit}>
                  <textarea
                    className="input-shell min-h-24 resize-none"
                    value={chatMessage}
                    onChange={(event) => setChatMessage(event.target.value)}
                    placeholder="Example: I need a two-wheeler slot for 3 hours near a low-demand area."
                  />
                  <button type="submit" className="button-primary w-full" disabled={loading}>
                    {loading ? "Asking Gemini..." : "Ask AI assistant"}
                  </button>
                </form>
                {chatResponse && (
                  <div className="mt-4 rounded-2xl bg-mint/10 p-4">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="text-sm font-semibold text-green-950">AI response</p>
                      <span className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-green-900">
                        {chatResponse.aiProvider}
                      </span>
                    </div>
                    <p className="mt-2 text-sm text-green-950">{chatResponse.reply}</p>
                    {chatResponse.retrievedContext && (
                      <p className="mt-2 text-xs text-green-900">
                        Grounded with {chatResponse.retrievedContext.availableSlots} available slots and{" "}
                        {chatResponse.retrievedContext.bookingHistoryRecords} booking-history records.
                      </p>
                    )}
                    {chatResponse.retrievedContext?.closestPriceOptions?.length > 0 && (
                      <div className="mt-3 rounded-2xl bg-white/80 p-3">
                        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-green-900">
                          Closest available prices
                        </p>
                        <div className="mt-2 space-y-2">
                          {chatResponse.retrievedContext.closestPriceOptions.map((slot) => (
                            <div key={slot.slotId} className="flex flex-wrap items-center justify-between gap-2 text-sm">
                              <span className="font-semibold text-green-950">
                                {slot.slotId} - {slot.location}
                              </span>
                              <span className="text-green-900">Rs {slot.totalPrice}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </section>

              <section>
                <p className="text-sm font-semibold text-ink">Choose your vehicle type</p>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  {[
                    { id: "two-wheeler", label: "Two-wheeler" },
                    { id: "four-wheeler", label: "Four-wheeler" },
                  ].map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      className={vehicleType === item.id ? "button-primary w-full" : "button-secondary w-full"}
                      onClick={() => {
                        setVehicleType(item.id);
                        setDurationHours(1);
                        setSelectedLocation("");
                        setRecommendation(null);
                      }}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
              </section>

              {vehicleType && (
                <section>
                  <label className="text-sm font-semibold text-ink" htmlFor="assistantDurationHours">
                    How many hours will you park?
                  </label>
                  <div className="mt-3 flex items-center gap-3">
                    <input
                      id="assistantDurationHours"
                      className="input-shell"
                      type="number"
                      min="1"
                      max="24"
                      value={durationHours}
                      onChange={(event) => {
                        setDurationHours(event.target.value);
                        setRecommendation(null);
                      }}
                    />
                    <span className="whitespace-nowrap text-sm font-semibold text-slate">hours</span>
                  </div>
                </section>
              )}

              {vehicleType && (
                <section>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <p className="text-sm font-semibold text-ink">Choose a location</p>
                    {options?.suggestedLocation && (
                      <span className="rounded-full bg-mint/15 px-3 py-1 text-xs font-semibold text-green-900">
                        Suggested: {options.suggestedLocation.location}
                      </span>
                    )}
                  </div>

                  {loading && !recommendation && <p className="mt-3 text-sm text-slate">Checking demand patterns...</p>}

                  <div className="mt-3 grid gap-3">
                    {locations.map((item) => (
                      <button
                        key={item.location}
                        type="button"
                        className={`rounded-2xl border p-4 text-left transition hover:-translate-y-0.5 ${
                          selectedLocation === item.location
                            ? "border-ink bg-white"
                            : "border-ink/10 bg-white/70 hover:border-ink/20"
                        }`}
                        onClick={() => {
                          setSelectedLocation(item.location);
                          setRecommendation(null);
                        }}
                      >
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <span className="font-semibold">{item.location}</span>
                          <span
                            className={`rounded-full px-3 py-1 text-xs font-semibold ${
                              demandClasses[item.demandLevel] || demandClasses.MEDIUM
                            }`}
                          >
                            {item.demandLevel} demand
                          </span>
                        </div>
                        <p className="mt-2 text-sm text-slate">
                          {item.availableSlots} of {item.totalSlots} slots available
                        </p>
                        <p className="mt-1 text-sm text-slate">{item.reason}</p>
                      </button>
                    ))}
                  </div>

                  {vehicleType && locations.length === 0 && !loading && (
                    <p className="mt-3 text-sm text-slate">No compatible parking locations are available right now.</p>
                  )}
                </section>
              )}

              {selectedLocation && !recommendation && (
                <button type="button" className="button-primary w-full" onClick={handleRecommend} disabled={loading}>
                  {loading ? "Finding best slot..." : "Suggest best slot"}
                </button>
              )}

              {recommendation && (
                <section className="rounded-2xl border border-mint/40 bg-mint/10 p-4">
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="text-xs uppercase tracking-[0.18em] text-green-900">Recommended Slot</p>
                      <h3 className="mt-1 text-2xl font-semibold text-green-950">
                        {recommendation.recommendedSlotId || "No slot available"}
                      </h3>
                    </div>
                    <span className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-green-900">
                      {Math.round((recommendation.score || 0) * 100)}%
                    </span>
                  </div>
                  <p className="mt-3 text-sm text-green-950">{recommendation.reason}</p>
                  <p className="mt-2 text-sm font-semibold text-green-950">{recommendation.paymentPrompt}</p>

                  {recommendation.nextStep === "PROCEED_TO_PAYMENT" && (
                    <button
                      type="button"
                      className="button-primary mt-4 w-full"
                      onClick={handleProceedToPayment}
                      disabled={booking}
                    >
                      {booking ? "Creating booking..." : "Proceed to payment"}
                    </button>
                  )}
                </section>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
};
