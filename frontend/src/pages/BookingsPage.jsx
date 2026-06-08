import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { bookingApi, getApiError } from "../api/client";
import { Loader } from "../components/Loader";
import { useToast } from "../context/ToastContext";
import { formatRupees } from "../utils/money";

const statusClasses = {
  pending: "bg-amber/20 text-amber-950",
  confirmed: "bg-mint/15 text-green-900",
  cancelled: "bg-slate/20 text-slate-700",
  expired: "bg-ember/15 text-red-900",
};

export const BookingsPage = () => {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeBookingId, setActiveBookingId] = useState("");
  const { pushToast } = useToast();

  const loadBookings = async () => {
    try {
      const response = await bookingApi.get("/bookings");
      setBookings(response.data);
    } catch (error) {
      pushToast({ title: "Failed to load bookings", description: getApiError(error), tone: "error" });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBookings();
  }, []);

  const handleCancel = async (bookingId) => {
    try {
      setActiveBookingId(bookingId);
      await bookingApi.post(`/bookings/${bookingId}/cancel`);
      pushToast({ title: "Booking cancelled", description: `${bookingId} was cancelled.`, tone: "success" });
      await loadBookings();
    } catch (error) {
      pushToast({ title: "Cancel failed", description: getApiError(error), tone: "error" });
    } finally {
      setActiveBookingId("");
    }
  };

  if (loading) {
    return <Loader label="Loading booking history..." />;
  }

  return (
    <div className="glass-panel p-6">
      <div className="mb-6">
        <h2 className="section-title">Booking history</h2>
        <p className="muted-copy">Track pending, confirmed, cancelled, and expired bookings in one place.</p>
      </div>

      <div className="space-y-4">
        {bookings.length === 0 && <p className="text-sm text-slate">No bookings available yet.</p>}
        {bookings.map((booking) => (
          <div key={booking.bookingId} className="rounded-3xl border border-ink/5 bg-white/75 p-5">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <div className="flex flex-wrap items-center gap-3">
                  <h3 className="text-xl font-semibold">{booking.bookingId}</h3>
                  <span className={`rounded-full px-3 py-1 text-xs font-semibold uppercase ${statusClasses[booking.status]}`}>
                    {booking.status}
                  </span>
                </div>
                <p className="mt-2 text-sm text-slate">
                  Slot {booking.slotId} • {formatRupees(booking.amount)} • Created {new Date(booking.createdAt).toLocaleString()}
                </p>
                {booking.status === "pending" && (
                  <p className="mt-2 text-sm text-amber-900">
                    Expires at {new Date(booking.expiresAt).toLocaleString()}
                  </p>
                )}
              </div>

              <div className="flex flex-wrap gap-3">
                {booking.status === "pending" && (
                  <Link className="button-primary" to={`/payment/${booking.bookingId}`}>
                    Complete payment
                  </Link>
                )}
                {["pending", "confirmed"].includes(booking.status) && (
                  <button
                    type="button"
                    className="button-danger"
                    onClick={() => handleCancel(booking.bookingId)}
                    disabled={activeBookingId === booking.bookingId}
                  >
                    {activeBookingId === booking.bookingId ? "Cancelling..." : "Cancel booking"}
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

