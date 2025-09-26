import boto3
import pytest

def test_aws_connectivity():
    # Test STS
    sts = boto3.client("sts")
    identity = sts.get_caller_identity()
    assert "Account" in identity

    # Test S3
    s3 = boto3.client("s3")
    buckets = s3.list_buckets()
    assert "Buckets" in buckets

    # Test Lambda
    lambda_client = boto3.client("lambda")
    lambdas = lambda_client.list_functions()
    assert "Functions" in lambdas

    print(f"AWS OK: {identity['Account']}, Buckets: {len(buckets['Buckets'])}, Lambdas: {len(lambdas['Functions'])}")
