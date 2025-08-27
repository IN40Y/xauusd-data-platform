output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/dev"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.xauusd_timeseries.name
}

output "data_fetcher_lambda_name" {
  description = "Name of the data fetcher Lambda function"
  value       = aws_lambda_function.data_fetcher.function_name
}

output "query_api_lambda_name" {
  description = "Name of the query API Lambda function"
  value       = aws_lambda_function.query_api.function_name
}
