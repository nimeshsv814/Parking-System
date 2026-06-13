resource "aws_dynamodb_table" "auth_users" {
  name         = var.auth_users_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

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

    key_schema {
      attribute_name = "role"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = var.auth_users_table
    Service     = "auth-service"
    Application = "smart-parking"
  }
}

resource "aws_dynamodb_table" "parking_slots" {
  name         = var.parking_slots_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "slotId"

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

    key_schema {
      attribute_name = "status"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "location"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "bookingId-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "bookingId"
      key_type       = "HASH"
    }
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = var.parking_slots_table
    Service     = "parking-service"
    Application = "smart-parking"
  }
}

resource "aws_dynamodb_table" "bookings" {
  name         = var.booking_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "bookingId"

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

    key_schema {
      attribute_name = "userId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "status-expiresAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "status"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "expiresAt"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "slotId-createdAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "slotId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = var.booking_table
    Service     = "booking-service"
    Application = "smart-parking"
  }
}

resource "aws_dynamodb_table" "payments" {
  name         = var.payment_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "paymentId"

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

    key_schema {
      attribute_name = "userId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "bookingId-createdAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "bookingId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "razorpayOrderId-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "razorpayOrderId"
      key_type       = "HASH"
    }
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = var.payment_table
    Service     = "payment-service"
    Application = "smart-parking"
  }
}

resource "aws_dynamodb_table" "notifications" {
  name         = var.notification_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "notificationId"

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

    key_schema {
      attribute_name = "recipientUserId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "bookingId-createdAt-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "bookingId"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "createdAt"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = var.notification_table
    Service     = "notification-service"
    Application = "smart-parking"
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
