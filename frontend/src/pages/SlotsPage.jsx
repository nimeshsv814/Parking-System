import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { aiApi, bookingApi, getApiError, parkingApi } from "../api/client";
import { Loader } from "../components/Loader";
import { SlotCard } from "../components/SlotCard";
import { useToast } from "../context/ToastContext";

export const SlotsPage = () => {
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(true);
  const [bookingSlotId, setBookingSlotId] = useState("");
  const [filter, setFilter] = useState("all");
  const [recommendation, setRecommendation] = useState(null);
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

  const handleBook = async (slotId) => {
    try {
      setBookingSlotId(slotId);
      const response = await bookingApi.post("/bookings", { slotId });
      pushToast({
        title: "Booking created",
        description: `Booking ${response.data.booking.bookingId} is pending payment.`,
        tone: "success",
      });
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
            action={slot.status === "available" ? () => handleBook(slot.slotId) : null}
            actionLabel={bookingSlotId === slot.slotId ? "Creating booking..." : "Book now"}
            disabled={bookingSlotId === slot.slotId}
            recommendation={recommendation}
          />
        ))}
      </div>
    </div>
  );
};

