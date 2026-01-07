# S3 Bucket
resource "aws_s3_bucket" "guardrail_bucket" {
  bucket = "guardrail-activity-logs-${random_id.suffix.hex}"
}
data "aws_caller_identity" "current" {}
resource "aws_s3_bucket_policy" "guardrail_bucket_policy" {
  bucket = aws_s3_bucket.guardrail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "${aws_s3_bucket.guardrail_bucket.arn}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.guardrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
# SNS Topic
resource "aws_sns_topic" "guardrail_alerts" {
  name = "root-account-alerts"
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_guardrail_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach basic Lambda policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach SNS publish permission
resource "aws_iam_policy" "lambda_sns" {
  name = "lambda_sns_publish"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.guardrail_alerts.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sns_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_sns.arn
}

# Lambda Function
resource "aws_lambda_function" "guardrail_lambda" {
  filename         = "lambda/lambda_function.zip" # We'll zip next
  function_name    = "root-account-alerts"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = filebase64sha256("lambda/lambda_function.zip")
}

# CloudTrail
resource "aws_cloudtrail" "guardrail_trail" {
  name                          = "root-guardrail-trail"
  s3_bucket_name                = aws_s3_bucket.guardrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }
  depends_on = [aws_s3_bucket_policy.guardrail_bucket_policy]
}


# EventBridge Rule
resource "aws_cloudwatch_event_rule" "root_activity" {
  name        = "root-account-activity"
  description = "Detects AWS root user activity"
  event_pattern = jsonencode({
    source        = ["aws.signin"]
    "detail-type" = ["AWS Console Sign-in via CloudTrail"]
    detail = {
      userIdentity = { type = ["Root"] }
    }
  })
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.root_activity.name
  arn  = aws_lambda_function.guardrail_lambda.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.guardrail_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.root_activity.arn
}

# Random suffix for unique bucket name
resource "random_id" "suffix" {
  byte_length = 4
}
