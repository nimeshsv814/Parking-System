resource "aws_dynamodb_table" "auth_users" {
  name                        = var.auth_users_table
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "userId"
  deletion_protection_enabled = var.enable_dynamodb_deletion_protection

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "role"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "role-createdAt-index"
    projection_type = "ALL"
    hash_key        = "role"
    range_key       = "createdAt"
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Application = "smart-parking"
    Service     = "auth-service"
  }
}

resource "aws_dynamodb_table" "parking_slots" {
  name                        = var.parking_slots_table
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "slotId"
  deletion_protection_enabled = var.enable_dynamodb_deletion_protection

  attribute {
    name = "slotId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "location"
    type = "S"
  }

  attribute {
    name = "bookingId"
    type = "S"
  }

  global_secondary_index {
    name            = "status-location-index"
    projection_type = "ALL"
    hash_key        = "status"
    range_key       = "location"
  }

  global_secondary_index {
    name            = "bookingId-index"
    projection_type = "ALL"
    hash_key        = "bookingId"
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Application = "smart-parking"
    Service     = "parking-service"
  }
}

resource "aws_dynamodb_table" "bookings" {
  name                        = var.booking_table
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "bookingId"
  deletion_protection_enabled = var.enable_dynamodb_deletion_protection

  attribute {
    name = "bookingId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "expiresAt"
    type = "S"
  }

  attribute {
    name = "slotId"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-createdAt-index"
    projection_type = "ALL"
    hash_key        = "userId"
    range_key       = "createdAt"
  }

  global_secondary_index {
    name            = "status-expiresAt-index"
    projection_type = "ALL"
    hash_key        = "status"
    range_key       = "expiresAt"
  }

  global_secondary_index {
    name            = "slotId-createdAt-index"
    projection_type = "ALL"
    hash_key        = "slotId"
    range_key       = "createdAt"
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Application = "smart-parking"
    Service     = "booking-service"
  }
}

resource "aws_dynamodb_table" "payments" {
  name                        = var.payment_table
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "paymentId"
  deletion_protection_enabled = var.enable_dynamodb_deletion_protection

  attribute {
    name = "paymentId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "bookingId"
    type = "S"
  }

  attribute {
    name = "razorpayOrderId"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-createdAt-index"
    projection_type = "ALL"
    hash_key        = "userId"
    range_key       = "createdAt"
  }

  global_secondary_index {
    name            = "bookingId-createdAt-index"
    projection_type = "ALL"
    hash_key        = "bookingId"
    range_key       = "createdAt"
  }

  global_secondary_index {
    name            = "razorpayOrderId-index"
    projection_type = "ALL"
    hash_key        = "razorpayOrderId"
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Application = "smart-parking"
    Service     = "payment-service"
  }
}

resource "aws_dynamodb_table" "notifications" {
  name                        = var.notification_table
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "notificationId"
  deletion_protection_enabled = var.enable_dynamodb_deletion_protection

  attribute {
    name = "notificationId"
    type = "S"
  }

  attribute {
    name = "recipientUserId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "bookingId"
    type = "S"
  }

  global_secondary_index {
    name            = "recipientUserId-createdAt-index"
    projection_type = "ALL"
    hash_key        = "recipientUserId"
    range_key       = "createdAt"
  }

  global_secondary_index {
    name            = "bookingId-createdAt-index"
    projection_type = "ALL"
    hash_key        = "bookingId"
    range_key       = "createdAt"
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Application = "smart-parking"
    Service     = "notification-service"
  }
}

locals {
  dynamodb_table_arns = [
    aws_dynamodb_table.auth_users.arn,
    aws_dynamodb_table.parking_slots.arn,
    aws_dynamodb_table.bookings.arn,
    aws_dynamodb_table.payments.arn,
    aws_dynamodb_table.notifications.arn
  ]

  dynamodb_table_index_arns = [
    for table_arn in local.dynamodb_table_arns : "${table_arn}/index/*"
  ]
}
