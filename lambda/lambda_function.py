import boto3
from datetime import datetime

sns = boto3.client("sns")

TOPIC_ARN = "arn:aws:sns:us-east-1:277841471514:root-account-alerts"

FREE_TIER_EC2 = ["t2.micro", "t3.micro"]

def lambda_handler(event, context):
    detail = event.get("detail", {})
    
    event_name = detail.get("eventName", "")
    event_source = detail.get("eventSource", "")
    user_identity = detail.get("userIdentity", {})
    user_type = user_identity.get("type", "")
    user_arn = user_identity.get("arn", "Unknown")
    source_ip = detail.get("sourceIPAddress", "Unknown")
    event_time = detail.get("eventTime", datetime.utcnow().isoformat())

    severity = None
    reason = None

    
    if user_type == "Root":
        severity = "CRITICAL"
        reason = "Root account activity detected"


    elif event_name == "CreateNatGateway":
        severity = "CRITICAL"
        reason = "NAT Gateway created (hourly billing starts immediately)"


    elif event_name == "CreateLoadBalancer":
        severity = "CRITICAL"
        reason = "Load balancer created (hourly cost applies)"


    elif event_name in ["CreateDBInstance", "ModifyDBInstance"]:
        severity = "CRITICAL"
        reason = "RDS database created or modified (likely outside Free Tier)"

    elif event_name == "RunInstances":
        instance_type = (
            detail.get("requestParameters", {})
            .get("instanceType", "")
        )

        if instance_type not in FREE_TIER_EC2:
            severity = "CRITICAL"
            reason = f"EC2 instance type {instance_type} is not Free Tier eligible"
        else:
            return {"status": "ignored - free tier EC2"}


    elif event_name == "CreateVolume":
        size = detail.get("requestParameters", {}).get("size", 0)

        if size > 30:
            severity = "HIGH"
            reason = f"EBS volume size {size}GB exceeds Free Tier limit"
        else:
            return {"status": "ignored - free tier EBS"}

  
    else:
        return {"status": "ignored"}

    message = f"""


Severity: {severity}
Reason: {reason}

Event: {event_name}
Service: {event_source}
Time: {event_time}
Source IP: {source_ip}
User ARN: {user_arn}

Recommended Action:
Review resource immediately to avoid unexpected charges.
"""

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject=f"{severity} AWS Cost Protection Alert",
        Message=message
    )

    return {"status": "alert sent"}

