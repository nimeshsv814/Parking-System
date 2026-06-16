import { useEffect, useState } from "react";
import { aiApi, bookingApi, getApiError, notificationApi, parkingApi } from "../api/client";
import { Loader } from "../components/Loader";
import { SlotCard } from "../components/SlotCard";
import { StatCard } from "../components/StatCard";
import { useToast } from "../context/ToastContext";

export const DashboardPage = () => {
  const [loading, setLoading] = useState(true);
  const [slots, setSlots] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [demandPrediction, setDemandPrediction] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const { pushToast } = useToast();

  useEffect(() => {
    const loadDashboard = async () => {
      try {
        const [slotsResponse, bookingsResponse, notificationsResponse, demandResponse] = await Promise.all([
          parkingApi.get("/slots"),
          bookingApi.get("/bookings"),
          notificationApi.get("/notifications"),
          aiApi.get("/demand-prediction?hours=4").catch(() => ({ data: [] })),
        ]);
        setSlots(slotsResponse.data);
        setBookings(bookingsResponse.data);
        setNotifications(notificationsResponse.data.slice(0, 4));
        setDemandPrediction(demandResponse.data);
      } catch (error) {
        pushToast({ title: "Failed to load dashboard", description: getApiError(error), tone: "error" });
      } finally {
        setLoading(false);
      }
    };

    loadDashboard();
  }, [pushToast]);

  if (loading) {
    return <Loader label="Loading dashboard insights..." />;
  }

  const availableSlots = slots.filter((slot) => slot.status === "available").length;
  const activeBookings = bookings.filter((booking) => ["pending", "confirmed"].includes(booking.status)).length;
  const currentDemand = demandPrediction[0]?.demandLevel || "LOW";

  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Available slots" value={availableSlots} accent="bg-mint" hint="Ready for immediate booking" />
        <StatCard label="My bookings" value={bookings.length} accent="bg-amber" hint="Complete history across statuses" />
        <StatCard label="Active bookings" value={activeBookings} accent="bg-ink" hint="Pending and confirmed reservations" />
        <StatCard
          label="Recent notifications"
          value={notifications.length}
          accent="bg-ember"
          hint="Latest booking and payment updates"
        />
        <StatCard label="Demand level" value={currentDemand} accent="bg-slate" hint="AI forecast for the next hour" />
      </div>

      <div className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
        <section className="glass-panel p-6">
          <div className="mb-5 flex items-center justify-between">
            <div>
              <h2 className="section-title">Hot slots</h2>
              <p className="muted-copy">A quick look at currently available parking spaces.</p>
            </div>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            {slots
              .filter((slot) => slot.status === "available")
              .slice(0, 4)
              .map((slot) => (
                <SlotCard key={slot.slotId} slot={slot} />
              ))}
          </div>
        </section>

        <section className="glass-panel p-6">
          <h2 className="section-title">Live activity</h2>
          <p className="muted-copy">Recent platform signals from the notification service.</p>
          <div className="mt-5 space-y-3">
            {notifications.length === 0 && <p className="text-sm text-slate">No notifications yet.</p>}
            {notifications.map((item) => (
              <div key={item._id} className="rounded-2xl border border-ink/5 bg-white/70 p-4">
                <div className="flex items-center justify-between gap-4">
                  <p className="text-sm font-semibold uppercase tracking-[0.2em] text-slate">{item.type}</p>
                  <span className="text-xs text-slate">{new Date(item.createdAt).toLocaleString()}</span>
                </div>
                <p className="mt-2 text-sm text-ink">{item.message}</p>
              </div>
            ))}
          </div>
        </section>
      </div>

      <section className="glass-panel p-6">
        <h2 className="section-title">Demand prediction</h2>
        <p className="muted-copy">AI forecast based on historical hourly booking averages.</p>
        <div className="mt-5 overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead>
              <tr className="text-slate">
                <th className="pb-3 pr-4 font-medium">Time</th>
                <th className="pb-3 pr-4 font-medium">Booked</th>
                <th className="pb-3 pr-4 font-medium">Available</th>
                <th className="pb-3 pr-4 font-medium">Demand</th>
              </tr>
            </thead>
            <tbody>
              {demandPrediction.map((item) => (
                <tr key={item.time} className="border-t border-ink/5">
                  <td className="py-3 pr-4 font-medium">{item.time}</td>
                  <td className="py-3 pr-4">{item.predictedBookedSlots}</td>
                  <td className="py-3 pr-4">{item.predictedAvailableSlots}</td>
                  <td className="py-3 pr-4 font-semibold">{item.demandLevel}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
};

