locals {
  app_labels = {
    Application = "smart-parking"
  }

  alb_paths = [
    "/auth",
    "/api/auth",
    "/parking",
    "/api/parking",
    "/booking",
    "/api/booking",
    "/ai",
    "/api/ai",
    "/payment",
    "/api/payment",
    "/notification",
    "/api/notification",
    "/"
  ]

  services = {
    auth = {
      name  = "auth-service"
      image = var.auth_service_image
      port  = 4001
      env = {
        PORT             = "4001"
        AWS_REGION       = var.aws_region
        AUTH_USERS_TABLE = var.auth_users_table
        JWT_EXPIRES_IN   = "7d"
        CORS_ORIGIN      = "*"
      }
      secret_env = ["JWT_SECRET", "SEED_ADMIN_EMAIL", "SEED_ADMIN_PASSWORD", "SEED_USER_EMAIL", "SEED_USER_PASSWORD"]
    }
    parking = {
      name  = "parking-service"
      image = var.parking_service_image
      port  = 4002
      env = {
        PORT                = "4002"
        AWS_REGION          = var.aws_region
        PARKING_SLOTS_TABLE = var.parking_slots_table
        CORS_ORIGIN         = "*"
      }
      secret_env = ["JWT_SECRET", "INTERNAL_API_KEY"]
    }
    booking = {
      name  = "booking-service"
      image = var.booking_service_image
      port  = 4003
      env = {
        PORT                     = "4003"
        AWS_REGION               = var.aws_region
        BOOKING_TABLE            = var.booking_table
        CORS_ORIGIN              = "*"
        PARKING_SERVICE_URL      = "http://parking-service:4002"
        NOTIFICATION_SERVICE_URL = "http://notification-service:4006"
        BOOKING_HOLD_MINUTES     = "10"
      }
      secret_env = ["JWT_SECRET", "INTERNAL_API_KEY", "GEMINI_API_KEY", "GEMINI_MODEL"]
    }
    payment = {
      name  = "payment-service"
      image = var.payment_service_image
      port  = 4004
      env = {
        PORT                     = "4004"
        AWS_REGION               = var.aws_region
        PAYMENT_TABLE            = var.payment_table
        CORS_ORIGIN              = "*"
        BOOKING_SERVICE_URL      = "http://booking-service:4003"
        NOTIFICATION_SERVICE_URL = "http://notification-service:4006"
        RAZORPAY_CURRENCY        = var.razorpay_currency
      }
      secret_env = ["JWT_SECRET", "INTERNAL_API_KEY", "RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET"]
    }
    scheduler = {
      name  = "scheduler-service"
      image = var.scheduler_service_image
      port  = 4005
      env = {
        PORT                = "4005"
        AWS_REGION          = var.aws_region
        BOOKING_TABLE       = var.booking_table
        BOOKING_SERVICE_URL = "http://booking-service:4003"
        CRON_SCHEDULE       = "* * * * *"
      }
      secret_env = ["INTERNAL_API_KEY"]
    }
    notification = {
      name  = "notification-service"
      image = var.notification_service_image
      port  = 4006
      env = {
        PORT               = "4006"
        AWS_REGION         = var.aws_region
        NOTIFICATION_TABLE = var.notification_table
        CORS_ORIGIN        = "*"
      }
      secret_env = ["JWT_SECRET", "INTERNAL_API_KEY"]
    }
    frontend = {
      name       = "frontend"
      image      = var.frontend_image
      port       = 80
      env        = {}
      secret_env = []
    }
  }

  app_secret_data = {
    JWT_SECRET          = var.jwt_secret
    INTERNAL_API_KEY    = var.internal_api_key
    SEED_ADMIN_EMAIL    = var.seed_admin_email
    SEED_ADMIN_PASSWORD = var.seed_admin_password
    SEED_USER_EMAIL     = var.seed_user_email
    SEED_USER_PASSWORD  = var.seed_user_password
    RAZORPAY_KEY_ID     = var.razorpay_key_id
    RAZORPAY_KEY_SECRET = var.razorpay_key_secret
    GEMINI_API_KEY      = var.gemini_api_key
    GEMINI_MODEL        = var.gemini_model
  }
}

resource "kubernetes_namespace" "quickslot" {
  metadata {
    name = var.namespace
  }

  depends_on = [aws_eks_node_group.this]
}

resource "kubernetes_secret" "app" {
  metadata {
    name      = "quickslot-runtime"
    namespace = kubernetes_namespace.quickslot.metadata[0].name
  }

  data = local.app_secret_data
  type = "Opaque"
}

resource "kubernetes_deployment" "app" {
  for_each = local.services

  metadata {
    name      = each.value.name
    namespace = kubernetes_namespace.quickslot.metadata[0].name

    labels = merge(local.app_labels, {
      app = each.value.name
    })
  }

  spec {
    replicas = each.key == "scheduler" ? 1 : 2

    selector {
      match_labels = {
        app = each.value.name
      }
    }

    template {
      metadata {
        labels = merge(local.app_labels, {
          app = each.value.name
        })
      }

      spec {
        service_account_name = kubernetes_service_account.app.metadata[0].name

        container {
          name  = each.value.name
          image = each.value.image

          port {
            container_port = each.value.port
          }

          dynamic "env" {
            for_each = each.value.env

            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "env" {
            for_each = toset(each.value.secret_env)

            content {
              name = env.value

              value_from {
                secret_key_ref {
                  name = kubernetes_secret.app.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = each.value.port
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  for_each = local.services

  metadata {
    name      = each.value.name
    namespace = kubernetes_namespace.quickslot.metadata[0].name
  }

  spec {
    selector = {
      app = each.value.name
    }

    port {
      port        = each.value.port
      target_port = each.value.port
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "kgateway" {
  metadata {
    name      = "quickslot-kgateway"
    namespace = kubernetes_namespace.quickslot.metadata[0].name
  }

  data = {
    "default.conf" = <<-CONF
server {
    listen 8080;
    server_name _;

    location = /health {
        return 200 "ok";
    }

    location /auth/ {
        rewrite ^/auth/(.*)$ /$1 break;
        proxy_pass http://auth-service:4001/;
    }

    location /api/auth/ {
        rewrite ^/api/auth/(.*)$ /$1 break;
        proxy_pass http://auth-service:4001;
    }

    location /parking/ {
        rewrite ^/parking/(.*)$ /$1 break;
        proxy_pass http://parking-service:4002/;
    }

    location /api/parking/ {
        rewrite ^/api/parking/(.*)$ /$1 break;
        proxy_pass http://parking-service:4002;
    }

    location /booking/ {
        rewrite ^/booking/(.*)$ /$1 break;
        proxy_pass http://booking-service:4003/;
    }

    location = /booking/book-slot {
        rewrite ^ /bookings break;
        proxy_pass http://booking-service:4003;
    }

    location = /api/booking/book-slot {
        rewrite ^ /bookings break;
        proxy_pass http://booking-service:4003;
    }

    location /api/booking/ {
        rewrite ^/api/booking/(.*)$ /$1 break;
        proxy_pass http://booking-service:4003;
    }

    location /ai/ {
        proxy_pass http://booking-service:4003/ai/;
    }

    location /api/ai/ {
        proxy_pass http://booking-service:4003/api/ai/;
    }

    location = /payment/create-order {
        rewrite ^ /payments/razorpay/order break;
        proxy_pass http://payment-service:4004;
    }

    location = /api/payment/create-order {
        rewrite ^ /payments/razorpay/order break;
        proxy_pass http://payment-service:4004;
    }

    location = /payment/verify-payment {
        rewrite ^ /payments/razorpay/verify break;
        proxy_pass http://payment-service:4004;
    }

    location = /api/payment/verify-payment {
        rewrite ^ /payments/razorpay/verify break;
        proxy_pass http://payment-service:4004;
    }

    location = /payment/process-payment {
        rewrite ^ /payments/process break;
        proxy_pass http://payment-service:4004;
    }

    location = /api/payment/process-payment {
        rewrite ^ /payments/process break;
        proxy_pass http://payment-service:4004;
    }

    location /payment/ {
        rewrite ^/payment/(.*)$ /$1 break;
        proxy_pass http://payment-service:4004/;
    }

    location /api/payment/ {
        rewrite ^/api/payment/(.*)$ /$1 break;
        proxy_pass http://payment-service:4004;
    }

    location /notification/ {
        rewrite ^/notification/(.*)$ /$1 break;
        proxy_pass http://notification-service:4006/;
    }

    location /api/notification/ {
        rewrite ^/api/notification/(.*)$ /$1 break;
        proxy_pass http://notification-service:4006;
    }

    location / {
        proxy_pass http://frontend:80;
    }
}
CONF
  }
}

resource "kubernetes_deployment" "kgateway" {
  metadata {
    name      = "quickslot-kgateway"
    namespace = kubernetes_namespace.quickslot.metadata[0].name

    labels = merge(local.app_labels, {
      app = "quickslot-kgateway"
    })
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "quickslot-kgateway"
      }
    }

    template {
      metadata {
        labels = merge(local.app_labels, {
          app = "quickslot-kgateway"
        })
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.27-alpine"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/nginx/conf.d"
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "config"

          config_map {
            name = kubernetes_config_map.kgateway.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kgateway" {
  metadata {
    name      = "quickslot-kgateway"
    namespace = kubernetes_namespace.quickslot.metadata[0].name
  }

  spec {
    selector = {
      app = "quickslot-kgateway"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "alb" {
  metadata {
    name      = "quickslot-alb"
    namespace = kubernetes_namespace.quickslot.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                                   = "alb"
      "alb.ingress.kubernetes.io/scheme"                              = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"                         = "ip"
      "alb.ingress.kubernetes.io/listen-ports"                        = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path"                    = "/health"
      "alb.ingress.kubernetes.io/load-balancer-name"                  = "${var.cluster_name}-alb"
      "alb.ingress.kubernetes.io/group.name"                          = "quickslot"
      "alb.ingress.kubernetes.io/subnets"                             = join(",", aws_subnet.public[*].id)
      "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "true"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        dynamic "path" {
          for_each = local.alb_paths

          content {
            path      = path.value
            path_type = "Prefix"

            backend {
              service {
                name = kubernetes_service.kgateway.metadata[0].name

                port {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_deployment.kgateway
  ]
}
