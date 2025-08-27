# Create DynamoDB table for time-series data
resource "aws_dynamodb_table" "xauusd_timeseries" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "timeframe"
  range_key    = "timestamp"

  attribute {
    name = "timeframe"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "XAUUSD-TimeSeries-Data"
  }
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "xauusd-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "xauusd-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.xauusd_timeseries.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Create Lambda function for data fetcher
resource "aws_lambda_function" "data_fetcher" {
  filename      = "${path.module}/lambda/data_fetcher/lambda.zip"
  function_name = "xauusd-data-fetcher"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.xauusd_timeseries.name
      API_KEY    = var.financial_data_api_key
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# Create Lambda function for query API
resource "aws_lambda_function" "query_api" {
  filename      = "${path.module}/lambda/query_api/lambda.zip"
  function_name = "xauusd-query-api"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.xauusd_timeseries.name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# EventBridge rule to trigger data fetcher
resource "aws_cloudwatch_event_rule" "data_fetcher_rule" {
  name                = "xauusd-data-fetcher-rule"
  schedule_expression = var.data_fetcher_schedule
}

resource "aws_cloudwatch_event_target" "data_fetcher_target" {
  rule      = aws_cloudwatch_event_rule.data_fetcher_rule.name
  target_id = "TriggerDataFetcher"
  arn       = aws_lambda_function.data_fetcher.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_fetcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_fetcher_rule.arn
}

# API Gateway for query API
resource "aws_apigatewayv2_api" "main" {
  name          = "xauusd-query-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "dev"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "query_api_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.query_api.invoke_arn
}

resource "aws_apigatewayv2_route" "get_rates" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /rates"
  target    = "integrations/${aws_apigatewayv2_integration.query_api_integration.id}"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*/rates"
}

# Zip the Lambda function code
data "archive_file" "data_fetcher" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/data_fetcher"
  output_path = "${path.module}/lambda/data_fetcher/lambda.zip"

  depends_on = [local_file.lambda_requirements]
}

data "archive_file" "query_api" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/query_api"
  output_path = "${path.module}/lambda/query_api/lambda.zip"

  depends_on = [local_file.lambda_requirements]
}

# Create requirements.txt for Lambda functions
resource "local_file" "lambda_requirements" {
  for_each = toset(["data_fetcher", "query_api"])

  filename = "${path.module}/lambda/${each.key}/requirements.txt"
  content  = file("${path.module}/lambda/${each.key}/requirements.txt")
}
