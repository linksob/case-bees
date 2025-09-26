set -e

#Run AWS integration
pytest tests/integration/aws/test_aws_connectivity.py --maxfail=1 --disable-warnings

#Run Glue jobs tests
pytest glue_jobs/tests --disable-warnings

#Run Lambda tests
pytest lambda_bronze/tests --disable-warnings
pytest lambda_api/test --disable-warnings

#Terraform init, plan, and apply
cd infra
terraform init
terraform plan
terraform apply -auto-approve
