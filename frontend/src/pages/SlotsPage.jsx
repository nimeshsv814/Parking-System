import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { aiApi, bookingApi, getApiError, parkingApi } from "../api/client";
import { Loader } from "../components/Loader";
import { SlotCard } from "../components/SlotCard";
import { useToast } from "../context/ToastContext";
import { formatRupees } from "../utils/money";

const vehicleOptions = [
  { id: "two-wheeler", label: "Two-wheeler" },
  { id: "four-wheeler", label: "Four-wheeler" },
];

export const SlotsPage = () => {
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(true);
  const [bookingSlotId, setBookingSlotId] = useState("");
  const [filter, setFilter] = useState("all");
  const [recommendation, setRecommendation] = useState(null);
  const [selectedSlot, setSelectedSlot] = useState(null);
  const [bookingForm, setBookingForm] = useState({ vehicleType: "four-wheeler", durationHours: 1 });
  const { pushToast } = useToast();
  const navigate = useNavigate();

  const loadSlots = async () => {
    try {
      const slotsResponse = await parkingApi.get("/slots");
      setSlots(slotsResponse.data);
      try {
        const recommendationResponse = await aiApi.get("/recommend-slot");
        setRecommendation(recommendationResponse.data);
      } catch (error) {
        setRecommendation(null);
      }
    } catch (error) {
      pushToast({ title: "Failed to load slots", description: getApiError(error), tone: "error" });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadSlots();
  }, []);

  const handleBook = async () => {
    if (!selectedSlot) {
      return;
    }

    try {
      setBookingSlotId(selectedSlot.slotId);
      const durationHours = Math.min(24, Math.max(1, Number(bookingForm.durationHours) || 1));
      const response = await bookingApi.post("/bookings", {
        slotId: selectedSlot.slotId,
        vehicleType: bookingForm.vehicleType,
        durationHours,
      });
      pushToast({
        title: "Booking created",
        description: `Booking ${response.data.booking.bookingId} is pending payment.`,
        tone: "success",
      });
      setSelectedSlot(null);
      navigate(`/payment/${response.data.booking.bookingId}`);
    } catch (error) {
      pushToast({ title: "Booking failed", description: getApiError(error), tone: "error" });
      setBookingSlotId("");
    }
  };

  const filteredSlots = filter === "all" ? slots : slots.filter((slot) => slot.status === filter);

  if (loading) {
    return <Loader label="Loading slot map..." />;
  }

  return (
    <div className="space-y-6">
      <div className="glass-panel flex flex-col gap-4 p-6 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h2 className="section-title">Parking slots</h2>
          <p className="muted-copy">Browse live slot statuses and book available spaces instantly.</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {["all", "available", "reserved", "occupied", "blocked"].map((item) => (
            <button
              key={item}
              type="button"
              className={filter === item ? "button-primary" : "button-secondary"}
              onClick={() => setFilter(item)}
            >
              {item}
            </button>
          ))}
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {filteredSlots.map((slot) => (
          <SlotCard
            key={slot.slotId}
            slot={slot}
            action={
              slot.status === "available"
                ? () => {
                    setSelectedSlot(slot);
                    setBookingForm({ vehicleType: "four-wheeler", durationHours: 1 });
                  }
                : null
            }
            actionLabel={bookingSlotId === slot.slotId ? "Creating booking..." : "Book now"}
            disabled={bookingSlotId === slot.slotId}
            recommendation={recommendation}
          />
        ))}
      </div>

      {selectedSlot && (
        <div className="fixed inset-0 z-50 flex items-end bg-ink/35 px-4 py-5 backdrop-blur-sm sm:items-center sm:justify-center">
          <div className="glass-panel w-full max-w-xl p-5 sm:p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.24em] text-slate">Booking details</p>
                <h3 className="mt-1 text-2xl font-semibold">Slot {selectedSlot.slotId}</h3>
                <p className="mt-2 text-sm text-slate">{selectedSlot.location}</p>
              </div>
              <button type="button" className="button-secondary px-4 py-2" onClick={() => setSelectedSlot(null)}>
                Close
              </button>
            </div>

            <div className="mt-6 space-y-5">
              <section>
                <p className="text-sm font-semibold text-ink">Vehicle type</p>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  {vehicleOptions.map((item) => (
                    <button
                      key={item.id}
                      type="button"
                      className={bookingForm.vehicleType === item.id ? "button-primary w-full" : "button-secondary w-full"}
                      onClick={() => setBookingForm((current) => ({ ...current, vehicleType: item.id }))}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
              </section>

              <section>
                <label className="text-sm font-semibold text-ink" htmlFor="durationHours">
                  Parking duration
                </label>
                <div className="mt-3 flex items-center gap-3">
                  <input
                    id="durationHours"
                    className="input-shell"
                    type="number"
                    min="1"
                    max="24"
                    value={bookingForm.durationHours}
                    onChange={(event) =>
                      setBookingForm((current) => ({ ...current, durationHours: event.target.value }))
                    }
                  />
                  <span className="whitespace-nowrap text-sm font-semibold text-slate">hours</span>
                </div>
              </section>

              <div className="rounded-2xl border border-ink/10 bg-white/70 p-4">
                <p className="text-sm text-slate">Estimated amount</p>
                <p className="mt-1 text-2xl font-semibold">
                  {formatRupees((Number(selectedSlot.price) || 0) * (Number(bookingForm.durationHours) || 1))}
                </p>
              </div>

              <button
                type="button"
                className="button-primary w-full"
                onClick={handleBook}
                disabled={bookingSlotId === selectedSlot.slotId}
              >
                {bookingSlotId === selectedSlot.slotId ? "Creating booking..." : "Continue to payment"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

