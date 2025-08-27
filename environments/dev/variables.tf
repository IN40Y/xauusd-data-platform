variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "financial_data_api_key" {
  description = "API key for the financial data provider (Twelve Data)"
  type        = string
  sensitive   = true
}

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "XauUsdTimeSeries"
}

variable "data_fetcher_schedule" {
  description = "Schedule expression for EventBridge rule"
  type        = string
  default     = "rate(5 minutes)"
}
