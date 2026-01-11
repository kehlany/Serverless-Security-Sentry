# AWS Guardrail Monitoring System

This project implements a serverless AWS security guardrail using CloudTrail, EventBridge, Lambda, and SNS.  
It detects critical account activity, like root sign-ins, IAM policy changes, S3 security modifications, and cost-impacting actions, and sends real-time alerts.

---

# Overview

Cloud environments generate a lot of events. Instead of manually reviewing logs, this system automates detection of high-risk activities and delivers alerts via email.

Incoming events are captured by CloudTrail, filtered through EventBridge rules, processed by Lambda for critical conditions, and then sent to an email via SNS.

## What This Project Covers

- **AWS CloudTrail**: Tracks all API activity across your account.  
- **Amazon EventBridge**: Defines rules for matching specific security and risk events.  
- **AWS Lambda (Python)**: Processes matched events, filters only the critical ones, and formats alert messages.  
- **Amazon SNS**: Sends email alerts to a subscribed administrator.


## How It Works

1. **CloudTrail** logs AWS API events.  
2. **EventBridge** applies rules to filter for events like root logins, IAM changes, and S3 policy changes.  
3. **Lambda function** receives the event, extracts relevant details, and evaluates if it’s critical.  
4. If critical, the Lambda publishes a formatted alert message via **SNS**.  
5. The subscribed email receives the alert with event details.

---

## Critical Events Monitored

- ConsoleLogin  
- EnableMFADevice  
- CreateUser  
- CreateRole  
- AttachRolePolicy  
- PutBucketPolicy  
- DeleteBucketPolicy  
- RunInstances

These are defined in the Lambda’s critical event list.

---

## Deployment

1. Create CloudTrail to record management events.  
2. Create EventBridge rules for specific patterns of critical events.  
3. Deploy the Lambda function with required permissions (sns:Publish and EventBridge invocation).  
4. Create an SNS topic and subscribe an admin email to receive alerts.  
5. Verify end-to-end flow by triggering safe test events.

---

## Usage

Once deployed:

- Perform an action that matches an EventBridge rule (e.g., create an IAM user).  
- Wait for Lambda to process the event.  
- Check the subscribed email for the alert.

This provides near real-time visibility for critical account changes without manual log review.

## Requirements

This project assumes:

- AWS IAM role for Lambda with permissions for SNS and EventBridge.  
- EventBridge rules targeting the Lambda function.  
- CloudTrail enabled in your AWS account.

---

## Code Structure

- lambda
- lambda_function.py: Main alerting logic  
- terraform/ (optional)  
- Infrastructure as code for deployment  


---

## Contributions

Contributions are welcome. Please open issues or pull requests for enhancements or additional event types.

---

## License

This project is provided under the MIT License.
