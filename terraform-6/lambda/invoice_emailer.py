import json
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3
from botocore.exceptions import ClientError


REGION = os.environ.get("AWS_REGION", "us-east-1")
AUTH_USERS_TABLE = os.environ["AUTH_USERS_TABLE"]
BOOKING_TABLE = os.environ["BOOKING_TABLE"]
PAYMENT_TABLE = os.environ["PAYMENT_TABLE"]
SENDER_EMAIL = os.environ["SENDER_EMAIL"]
URL_EXPIRY_SECONDS = int(os.environ.get("URL_EXPIRY_SECONDS", "86400"))

s3 = boto3.client("s3", region_name=REGION)
dynamodb = boto3.resource("dynamodb", region_name=REGION)
ses = boto3.client("ses", region_name=REGION)


def _get_s3_event_detail(event):
    detail = event.get("detail") or {}
    bucket = (detail.get("bucket") or {}).get("name")
    key = (detail.get("object") or {}).get("key")
    if not bucket or not key:
        raise ValueError("EventBridge event does not contain S3 bucket/key detail")
    return bucket, unquote_plus(key)


def _get_metadata(bucket, key):
    response = s3.head_object(Bucket=bucket, Key=key)
    return response.get("Metadata") or {}


def _get_item(table_name, key):
    try:
        response = dynamodb.Table(table_name).get_item(Key=key)
        return response.get("Item")
    except ClientError as exc:
        print(f"DynamoDB lookup failed for {table_name}: {exc}")
        return None


def _find_payment_by_id(payment_id):
    if not payment_id:
        return None
    return _get_item(PAYMENT_TABLE, {"paymentId": payment_id})


def _find_booking_by_id(booking_id):
    if not booking_id:
        return None
    return _get_item(BOOKING_TABLE, {"bookingId": booking_id})


def _find_user_by_id(user_id):
    if not user_id:
        return None
    return _get_item(AUTH_USERS_TABLE, {"userId": user_id})


def _resolve_recipient(metadata):
    booking_id = metadata.get("bookingid")
    payment_id = metadata.get("paymentid")
    user_id = metadata.get("userid")

    payment = _find_payment_by_id(payment_id)
    booking = _find_booking_by_id(booking_id or (payment or {}).get("bookingId"))
    user = _find_user_by_id(user_id or (booking or {}).get("userId") or (payment or {}).get("userId"))

    email = (
        metadata.get("email")
        or (booking or {}).get("userEmail")
        or (user or {}).get("email")
        or (user or {}).get("userId")
        or user_id
    )

    if not email or "@" not in str(email):
        raise ValueError(f"Could not resolve recipient email for booking={booking_id} payment={payment_id} user={user_id}")

    return {
        "email": str(email).strip().lower(),
        "booking_id": booking_id or (booking or {}).get("bookingId") or (payment or {}).get("bookingId") or "N/A",
        "payment_id": payment_id or (payment or {}).get("paymentId") or "N/A",
        "amount": (payment or {}).get("amount") or (booking or {}).get("amount") or "N/A",
    }


def _create_download_url(bucket, key):
    return s3.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": bucket,
            "Key": key,
            "ResponseContentType": "application/pdf",
        },
        ExpiresIn=URL_EXPIRY_SECONDS,
    )


def _send_email(recipient, download_url, bucket, key):
    expires_hours = max(1, round(URL_EXPIRY_SECONDS / 3600))
    subject = f"QuickSlot invoice for booking {recipient['booking_id']}"
    body_text = f"""Hi,

Your QuickSlot invoice is ready.

Booking ID: {recipient['booking_id']}
Payment ID: {recipient['payment_id']}
Amount: {recipient['amount']}

Download invoice:
{download_url}

This link expires in about {expires_hours} hour(s).

Thank you,
QuickSlot
"""

    body_html = f"""<html><body>
<p>Hi,</p>
<p>Your QuickSlot invoice is ready.</p>
<ul>
  <li><strong>Booking ID:</strong> {recipient['booking_id']}</li>
  <li><strong>Payment ID:</strong> {recipient['payment_id']}</li>
  <li><strong>Amount:</strong> {recipient['amount']}</li>
</ul>
<p><a href="{download_url}">Download invoice PDF</a></p>
<p>This link expires in about {expires_hours} hour(s).</p>
<p>Thank you,<br/>QuickSlot</p>
</body></html>"""

    return ses.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [recipient["email"]]},
        Message={
            "Subject": {"Data": subject, "Charset": "UTF-8"},
            "Body": {
                "Text": {"Data": body_text, "Charset": "UTF-8"},
                "Html": {"Data": body_html, "Charset": "UTF-8"},
            },
        },
        Tags=[
            {"Name": "Application", "Value": "smart-parking"},
            {"Name": "Event", "Value": "invoice-created"},
        ],
    )


def handler(event, context):
    print(json.dumps({"receivedAt": datetime.now(timezone.utc).isoformat(), "event": event}))
    bucket, key = _get_s3_event_detail(event)

    if not key.lower().endswith(".pdf"):
        print(f"Skipping non-PDF invoice object: s3://{bucket}/{key}")
        return {"skipped": True, "reason": "not-pdf", "bucket": bucket, "key": key}

    metadata = _get_metadata(bucket, key)
    recipient = _resolve_recipient(metadata)
    download_url = _create_download_url(bucket, key)
    response = _send_email(recipient, download_url, bucket, key)

    return {
        "sent": True,
        "messageId": response.get("MessageId"),
        "recipient": recipient["email"],
        "bucket": bucket,
        "key": key,
    }
