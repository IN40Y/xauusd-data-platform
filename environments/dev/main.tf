module "xauusd_infrastructure" {
  source = "../../modules/core-infrastructure"

  # Pass variables to the module
  aws_region             = var.aws_region
  financial_data_api_key = var.financial_data_api_key
  table_name             = var.table_name
  data_fetcher_schedule  = var.data_fetcher_schedule
}

# Output the API Gateway endpoint for easy access
output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL for the query API"
  value       = module.xauusd_infrastructure.api_gateway_endpoint
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.xauusd_infrastructure.dynamodb_table_name
}
