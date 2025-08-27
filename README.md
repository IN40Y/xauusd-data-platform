# XAU/USD Data Platform

A serverless AWS infrastructure for fetching, storing, and serving XAU/USD (Gold vs. US Dollar) financial data using Terraform and Python.

## Architecture
<img width="767" height="318" alt="xauusd drawio" src="https://github.com/user-attachments/assets/64ab2795-0384-4b89-849d-a92b5651e2a0" />

- **Data Source**: Twelve Data API (free tier supported)
- **Infrastructure as Code**: Terraform
- **Compute**: AWS Lambda (Python 3.9)
- **Database**: Amazon DynamoDB (time-series data)
- **Scheduling**: Amazon EventBridge
- **API**: Amazon API Gateway HTTP API

## Features

- Automated data fetching every 5 minutes
- Pre-aggregation of 1min, 5min, and 1h timeframes
- RESTful API for querying historical data
- Auto-expiration of old data (7 days TTL)
- Full infrastructure as code
- CI/CD pipeline with GitHub Actions

## Setup

### Prerequisites

1. AWS Account with CLI configured
2. Twelve Data API account (free tier)
3. Terraform >= 1.0.0
4. Python 3.9+

### Deployment

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/xauusd-data-platform.git
   cd xauusd-data-platform
   ```
