import os
import pytest
from unittest import mock
from app.lambda_api_gold import lambda_handler


@mock.patch.dict(os.environ, {
    "ATHENA_DB": "test_db",
    "ATHENA_TABLE": "test_table",
    "ATHENA_OUTPUT": "s3://test-athena/",
    "ATHENA_WORKGROUP": "primary"
})

def test_lambda_handler_runs():
    event = {"queryStringParameters": {"date": "2023-01-01", "city": "Sao Paulo"}}
    result = lambda_handler(event, {})
    assert isinstance(result, dict)
    assert "statusCode" in result
    assert "body" in result
