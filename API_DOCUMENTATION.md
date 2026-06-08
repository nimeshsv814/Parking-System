# Smart Parking System API

## Auth Service (`http://localhost:4001`)

### `POST /register`
Request:
```json
{
  "name": "Jane User",
  "email": "jane@example.com",
  "password": "Password123!",
  "role": "user"
}
```
Response:
```json
{
  "message": "Registration successful",
  "token": "jwt-token",
  "user": {
    "id": "user-id",
    "name": "Jane User",
    "email": "jane@example.com",
    "role": "user"
  }
}
```

### `POST /login`
Request:
```json
{
  "email": "jane@example.com",
  "password": "Password123!"
}
```

## Parking Service (`http://localhost:4002`)

### `GET /slots`
Returns all slots.

### `GET /slots/available`
Returns slots with `status=available`.

### `POST /slots` (Admin)
Request:
```json
{
  "slotId": "A-101",
  "location": "North Deck - L1",
  "price": 80
}
```

### `PATCH /slots/:slotId/status` (Admin)
Request:
```json
{
  "status": "blocked"
}
```

## Booking Service (`http://localhost:4003`)

### `POST /bookings`
Request:
```json
{
  "slotId": "A-101"
}
```

### `GET /bookings`
User sees own bookings. Admin sees all.

### `GET /bookings/:bookingId`
Returns a single booking for the owner or admin.

### `POST /bookings/:bookingId/cancel`
Cancels a pending or confirmed booking and releases the slot.

## Payment Service (`http://localhost:4004`)

### `POST /payments/razorpay/order`
Creates a Razorpay order for a pending booking. The response includes the public `keyId` needed by Razorpay Checkout.
Request:
```json
{
  "bookingId": "BKG-123456"
}
```
Response:
```json
{
  "keyId": "rzp_test_or_live_key",
  "order": {
    "id": "order_razorpay_id",
    "amount": 8000,
    "currency": "INR"
  },
  "booking": {
    "bookingId": "BKG-123456",
    "status": "pending"
  }
}
```

### `POST /payments/razorpay/verify`
Verifies the Razorpay Checkout response signature. On success, the booking is confirmed.
Request:
```json
{
  "bookingId": "BKG-123456",
  "razorpay_order_id": "order_razorpay_id",
  "razorpay_payment_id": "pay_razorpay_id",
  "razorpay_signature": "signature_from_checkout"
}
```
Response:
```json
{
  "message": "Payment verified",
  "payment": {
    "paymentId": "PAY-123456",
    "status": "success"
  },
  "booking": {
    "bookingId": "BKG-123456",
    "status": "confirmed"
  }
}
```

### `POST /payments/process`
Legacy mock payment endpoint.
Request:
```json
{
  "bookingId": "BKG-123456",
  "method": "card",
  "simulateSuccess": true
}
```
Response:
```json
{
  "message": "Payment successful",
  "payment": {
    "paymentId": "PAY-123456",
    "status": "success"
  },
  "booking": {
    "bookingId": "BKG-123456",
    "status": "confirmed"
  }
}
```

## Notification Service (`http://localhost:4006`)

### `GET /notifications`
User sees their notifications. Admin sees all notifications.

## Seed Users

- Admin: `admin@parking.com` / `Admin@123`
- User: `user@parking.com` / `User@123`

