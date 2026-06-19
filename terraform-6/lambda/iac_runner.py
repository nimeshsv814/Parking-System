import json
import os
from datetime import datetime, timezone


def handler(event, context):
    request = event.get("request", event)
    action = request.get("action", "plan")
    environment = request.get("environment", "dev")
    template = request.get("template", "quickslot-prod-like-dev")
    ttl_hours = request.get("ttl_hours")

    if action == "destroy":
        return {
            "status": "blocked",
            "reason": "Destroy requests are blocked by the QuickSlot IaC runner.",
        }

    return {
        "status": "accepted",
        "runner": "quickslot-iac-runner",
        "region": os.getenv("DEFAULT_REGION", "us-east-1"),
        "received_at": datetime.now(timezone.utc).isoformat(),
        "request": {
            "action": action,
            "environment": environment,
            "template": template,
            "ttl_hours": ttl_hours,
            "variables": request.get("variables", {}),
        },
        "note": "Placeholder runner created by Terraform. Wire Terraform/CDK execution here when ready.",
    }
