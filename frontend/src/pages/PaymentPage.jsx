import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { bookingApi, getApiError, paymentApi } from "../api/client";
import { Loader } from "../components/Loader";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../context/ToastContext";

const loadRazorpayCheckout = () =>
  new Promise((resolve, reject) => {
    if (window.Razorpay) {
      resolve(true);
      return;
    }

    const script = document.createElement("script");
    script.src = "https://checkout.razorpay.com/v1/checkout.js";
    script.onload = () => resolve(true);
    script.onerror = () => reject(new Error("Unable to load Razorpay Checkout"));
    document.body.appendChild(script);
  });

export const PaymentPage = () => {
  const { bookingId } = useParams();
  const [booking, setBooking] = useState(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const { user } = useAuth();
  const { pushToast } = useToast();
  const navigate = useNavigate();

  useEffect(() => {
    const loadBooking = async () => {
      try {
        const response = await bookingApi.get(`/bookings/${bookingId}`);
        setBooking(response.data);
      } catch (error) {
        pushToast({ title: "Failed to load booking", description: getApiError(error), tone: "error" });
      } finally {
        setLoading(false);
      }
    };

    loadBooking();
  }, [bookingId, pushToast]);

  const handlePayment = async () => {
    try {
      setProcessing(true);

      await loadRazorpayCheckout();
      const orderResponse = await paymentApi.post("/payments/razorpay/order", { bookingId });
      const { keyId, order } = orderResponse.data;

      const options = {
        key: keyId,
        amount: order.amount,
        currency: order.currency,
        name: "Smart Parking",
        description: `Booking ${bookingId}`,
        order_id: order.id,
        prefill: {
          name: user?.name || "",
          email: user?.email || "",
        },
        notes: {
          bookingId,
        },
        theme: {
          color: "#111827",
        },
        handler: async (razorpayResponse) => {
          try {
            const verifyResponse = await paymentApi.post("/payments/razorpay/verify", {
              bookingId,
              razorpay_order_id: razorpayResponse.razorpay_order_id,
              razorpay_payment_id: razorpayResponse.razorpay_payment_id,
              razorpay_signature: razorpayResponse.razorpay_signature,
            });

            pushToast({
              title: "Payment successful",
              description: `Booking ${verifyResponse.data.booking.bookingId} is now confirmed.`,
              tone: "success",
            });
            navigate("/bookings");
          } catch (error) {
            pushToast({ title: "Payment verification failed", description: getApiError(error), tone: "error" });
          } finally {
            setProcessing(false);
          }
        },
        modal: {
          ondismiss: () => {
            setProcessing(false);
          },
        },
      };

      const checkout = new window.Razorpay(options);
      checkout.on("payment.failed", (response) => {
        pushToast({
          title: "Payment failed",
          description: response.error?.description || "Razorpay could not complete the payment.",
          tone: "error",
        });
        setProcessing(false);
      });
      checkout.open();
    } catch (error) {
      pushToast({ title: "Payment result", description: getApiError(error), tone: "error" });
      setProcessing(false);
    }
  };

  if (loading) {
    return <Loader label="Loading payment details..." />;
  }

  if (!booking) {
    return <div className="glass-panel p-6 text-sm text-slate">Booking could not be found.</div>;
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_0.9fr]">
      <section className="glass-panel p-6">
        <p className="text-sm uppercase tracking-[0.3em] text-slate">Checkout</p>
        <h2 className="mt-3 font-serif text-5xl italic">Booking payment</h2>
        <p className="mt-4 max-w-xl text-slate">
          Complete the Razorpay payment to confirm your slot. If payment is not completed in time, the scheduler will
          release the reservation automatically.
        </p>
        <div className="mt-8 grid gap-4 sm:grid-cols-3">
          <div className="rounded-3xl bg-white/70 p-5">
            <p className="text-sm text-slate">Booking ID</p>
            <p className="mt-2 text-xl font-semibold">{booking.bookingId}</p>
          </div>
          <div className="rounded-3xl bg-white/70 p-5">
            <p className="text-sm text-slate">Slot</p>
            <p className="mt-2 text-xl font-semibold">{booking.slotId}</p>
          </div>
          <div className="rounded-3xl bg-white/70 p-5">
            <p className="text-sm text-slate">Amount</p>
            <p className="mt-2 text-xl font-semibold">Rs {booking.amount}</p>
          </div>
        </div>
      </section>

      <section className="glass-panel p-6">
        <h3 className="text-2xl font-semibold">Razorpay checkout</h3>
        <div className="mt-6 space-y-4">
          <div className="rounded-3xl border border-ink/10 bg-white/70 p-4">
            <p className="text-sm font-medium">Secure payment</p>
            <p className="mt-2 text-sm text-slate">
              Razorpay will open in a secure checkout window. Your booking is confirmed only after server-side signature
              verification succeeds.
            </p>
          </div>
          <button type="button" className="button-primary w-full" onClick={handlePayment} disabled={processing}>
            {processing ? "Opening checkout..." : `Pay Rs ${booking.amount}`}
          </button>
        </div>
      </section>
    </div>
  );
};

