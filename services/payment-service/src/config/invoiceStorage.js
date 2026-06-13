const { PutObjectCommand, S3Client } = require("@aws-sdk/client-s3");

const region = process.env.AWS_REGION || "us-east-1";
const bucketName = process.env.PAYMENT_INVOICE_BUCKET;
const kmsKeyArn = process.env.PAYMENT_INVOICE_KMS_KEY_ARN;

const s3Client = new S3Client({ region });

const buildInvoiceKey = ({ paymentId, bookingId }) => {
  const safeBookingId = String(bookingId || "unknown").replace(/[^A-Za-z0-9._-]/g, "-");
  const safePaymentId = String(paymentId || Date.now()).replace(/[^A-Za-z0-9._-]/g, "-");
  const datePrefix = new Date().toISOString().slice(0, 10);
  return `payment-invoices/${datePrefix}/${safeBookingId}/${safePaymentId}.json`;
};

const uploadPaymentInvoice = async ({ payment, booking, provider = "razorpay" }) => {
  if (!bucketName) {
    console.warn("Payment invoice upload skipped: PAYMENT_INVOICE_BUCKET is not configured");
    return null;
  }

  const createdAt = new Date().toISOString();
  const key = buildInvoiceKey({
    paymentId: payment.paymentId,
    bookingId: payment.bookingId,
  });
  const invoice = {
    invoiceId: `INV-${payment.paymentId}`,
    createdAt,
    provider,
    payment: {
      paymentId: payment.paymentId,
      bookingId: payment.bookingId,
      userId: payment.userId,
      amount: payment.amount,
      method: payment.method,
      status: payment.status,
      transactionRef: payment.transactionRef,
      razorpayOrderId: payment.razorpayOrderId,
      razorpayPaymentId: payment.razorpayPaymentId,
    },
    booking: {
      bookingId: booking.bookingId,
      userId: booking.userId,
      userEmail: booking.userEmail,
      slotId: booking.slotId,
      amount: booking.amount,
      status: booking.status,
      paidAt: booking.paidAt,
    },
  };

  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: key,
    Body: JSON.stringify(invoice, null, 2),
    ContentType: "application/json",
    ServerSideEncryption: "aws:kms",
    SSEKMSKeyId: kmsKeyArn,
    Metadata: {
      paymentId: String(payment.paymentId),
      bookingId: String(payment.bookingId),
      userId: String(payment.userId),
    },
  });

  await s3Client.send(command);
  console.log(`Payment invoice uploaded to s3://${bucketName}/${key}`);

  return {
    invoiceS3Bucket: bucketName,
    invoiceS3Key: key,
    invoiceKmsKeyArn: kmsKeyArn,
    invoiceCreatedAt: createdAt,
  };
};

module.exports = { uploadPaymentInvoice };
