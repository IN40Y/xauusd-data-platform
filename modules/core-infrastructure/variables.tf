variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "financial_data_api_key" {
  description = "API key for the financial data provider"
  type        = string
  sensitive   = true
}

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "data_fetcher_schedule" {
  description = "Schedule expression for EventBridge rule"
  type        = string
}
