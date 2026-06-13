const { PutObjectCommand, S3Client } = require("@aws-sdk/client-s3");

const bucketName = process.env.PAYMENT_INVOICE_BUCKET;
const kmsKeyId = process.env.PAYMENT_INVOICE_KMS_KEY_ID;
const region = process.env.AWS_REGION || "us-east-1";

const s3Client = new S3Client({ region });

const buildInvoiceKey = (paymentId) => {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `invoices/${year}/${month}/${paymentId}.json`;
};

const uploadPaymentInvoice = async ({ payment, booking, method, razorpayPaymentId }) => {
  if (!bucketName) {
    return null;
  }

  const generatedAt = new Date().toISOString();
  const key = buildInvoiceKey(payment.paymentId);
  const invoice = {
    invoiceId: `INV-${payment.paymentId}`,
    generatedAt,
    payment: {
      paymentId: payment.paymentId,
      bookingId: payment.bookingId,
      userId: payment.userId,
      amount: payment.amount,
      method,
      status: payment.status,
      transactionRef: payment.transactionRef,
      razorpayOrderId: payment.razorpayOrderId,
      razorpayPaymentId,
    },
    booking: {
      bookingId: booking.bookingId,
      slotId: booking.slotId,
      status: booking.status,
      userId: booking.userId,
      userEmail: booking.userEmail,
      paidAt: booking.paidAt,
    },
  };

  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: key,
    Body: JSON.stringify(invoice, null, 2),
    ContentType: "application/json",
    ServerSideEncryption: "aws:kms",
    SSEKMSKeyId: kmsKeyId || undefined,
    Metadata: {
      paymentId: payment.paymentId,
      bookingId: payment.bookingId,
      invoiceId: invoice.invoiceId,
    },
  });

  await s3Client.send(command);

  return {
    bucket: bucketName,
    key,
    kmsKeyId,
    invoiceId: invoice.invoiceId,
    generatedAt,
  };
};

module.exports = { uploadPaymentInvoice };

