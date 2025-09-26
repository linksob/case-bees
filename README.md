<p align="left">
  <img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white"/>
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white"/>
  <img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Spark-E25A1C?style=for-the-badge&logo=apachespark&logoColor=white"/>
  <img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white"/>
</p>


# BEES Brewery Data Lake Pipeline Project

## Overview

The pipeline ingests data from a public breweries API, capturing information about breweries such as name, location, and type. This raw data is first stored in the Bronze layer (as-ingested, partitioned NDJSON), then cleaned and enriched in the Silver layer, and finally aggregated and optimized for analytics in the Gold layer. Each stage is managed and automated using AWS Glue, Lambda, and Terraform, making the data available for queries and APIs.

This project implements a modern data pipeline on AWS, using Glue, Lambda, S3, Athena, Lake Formation, Step Functions, and Infrastructure as Code with Terraform. The goal is to orchestrate the ingestion, transformation, and exposure of brewery data, following best practices for modularization, automation, and security.

The main goal is to demonstrate skills in building cloud-based data pipelines, including Spark and SQL processing, data ingestion, transformation, and making data available for analytics and APIs.
 __OBS__: Regards some features isn't the best choice for the optimus performance it is just to show up the skills requested by the case.

---

## Project architecture

<p align="center">
  <img src="Architeture.png" alt="Project Architecture" style="max-width: 100%; height: auto;"/>
</p>

## Project Structure


```
case-bees/
├── glue_jobs/                # Glue ETLs
│   ├── app/                  # Jobs code
│   └── tests/                # Unit tests for jobs
│
├── infra/                    # Infrastructure as code (Terraform)
│   ├── *.tf                  # AWS resources
│   └── policies/             # External IAM policies and trust (JSON)
│
├── lambda_api/               # Lambda for API 
│   ├── app/                  # Lambda code
│   └── test/                 # Unit tests for the API Lambda
│
├── lambda_bronze/            # Bronze ingestion Lambda
│   ├── app/                  # Lambda code
│   └── tests/                # Unit tests for bronze_api
│
├── orchestration/            # Orchestration (Step Functions)
│   └── stepfunction_bees_brewery_pipeline.json
│
├── tests/
│   └── integration/
│       └── test_aws_connectivity.py  # AWS integration test
│
├── .dockerignore             # Files ignored in Docker build
├── .env                      # Env variables for AWS Access
├── docker-entrypoint.sh      # Container entry script
├── Dockerfile                # Automated environment for tests and deployment
├── .gitignore                # Files ignored by git
├── README.md                 # This file
└── requirements.txt          # Python dependencies
```

---

## Components Created

- **Glue Jobs:** ETLs to transform data between Bronze, Silver, and Gold layers.
  - ``job_bees_brewery_bronze_to_silver``: Ingest from layer Bronze to Silver
  - ``job_bees_brewery_silver_to_gold``: Ingest from layer Silver to Gold
- **Lambdas:**
  - `lambda_bronze`: Ingests external data to S3 (NDJSON, partitioned).
  - `lambda_api`: Athena query with parameters (transaction_date, brewery_id) via API Gateway.
- **Infrastructure:**
  - All infrastructure is provisioned using **Terraform** (files in `infra/`).
  - **S3 Buckets:**
    - `bees-breweries-athena-query-results`
    - `bees-brewery-data-bronze`
    - `bees-brewery-data-silver`
    - `bees-brewery-data-gold`
    - `bees-brewery-scripts`
  - **Glue Databases & Tables:**
    - Database: `db_bees_bronze` / Table: `tb_bees_breweries_bronze`
    - Database: `db_bees_silver` / Table: `tb_bees_breweries_silver`
    - Database: `db_bees_gold` / Table: `tb_bees_breweries_gold`
  - **Lambda Functions:**
    - `lambda_bronze` (bronze ingestion)
    - `lambda_api_gold` (API)
  - **Step Functions:**
    - `bees_brewery_pipeline` (orchestration)
  - **EventBridge:**
    - `bees_brewery_eventbridge` (event rule to start the flux)
  - **SNS Topic:**
    - `bees_alert_topic`: Alert and monitoring
  - **API Gateway:**
    - `gold-api` (REST API calling lambda function)
  - **IAM Roles & Policies:**
    - Roles: `lakeformation_user_bronze`, `lakeformation_user_silver`, `lakeformation_user_gold`, `glue_bees_breweries_role`, `lambda_bronze_role`, `lambda_api_gold_role`
    - Policies: All custom policies are externalized in `infra/policies/policy/*.json` and referenced via `file()` in Terraform.
- **Tests:**
  - Unit (pytest, moto, mock).
  - AWS integration (boto3).
- **Automation and container:**
  - Dockerfile and entrypoint to run all tests and Terraform end-to-end.

---

## How to Run on Another Machine

### 1. Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- AWS account with valid credentials (Access Key, Secret Key, region)

### 2. Clone the repository
```sh
git clone https://github.com/linksob/case-bees.git
cd case-bees
```

### 3. Set AWS credentials
The recommended way is to use a `.env` file (not versioned) with your credentials:

Create a file named `.env` in the project root with:

```
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
AWS_DEFAULT_REGION=us-east-1
```

**Security note:** Never commit your `.env` or credentials to version control. For production/CI, use secure environment variables (e.g., GitHub Actions secrets) instead of files.

### 4. Build the Docker image
```sh
docker build -t bees-pipeline .
```
### 5. Run the Docker image
```sh
docker run --rm -it --env-file .env -v $(pwd):/workspace bees-pipeline
```

### 5. What does the container do?
- Runs AWS integration test (STS, S3, Lambda)
- Runs all unit tests (Glue, Lambdas)
- Runs `terraform init`, `plan`, and `apply` (infra/)
- Shows the result of all tests and Terraform

---

## Notes
- AWS credentials must have permission to create/modify resources (S3, Glue, Lambda, IAM, etc).
- The pipeline is modular: you can run only parts (e.g., just tests, just Terraform).
  - **To run only unit tests:**
    ```sh
    docker run --rm -it --env-file .env -v $(pwd):/workspace bees-pipeline pytest glue_jobs/tests lambda_bronze/tests lambda_api/test
    ```
  - **To run only integration test:**
    ```sh
    docker run --rm -it --env-file .env -v $(pwd):/workspace bees-pipeline pytest tests/integration
    ```
  - **To run only Terraform:**
    ```sh
    docker run --rm -it --env-file .env -v $(pwd):/workspace bees-pipeline bash -c "cd infra && terraform init && terraform plan && terraform apply"
    ```
- Data partitioning follows Hive style (transaction_date=YYYY-MM-DD).

---

## Contact
Questions or suggestions: [linksob](https://github.com/linksob)
Email: lincoln.sobral@hotmail.com
