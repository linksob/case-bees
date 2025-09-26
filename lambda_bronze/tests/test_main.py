import os
import pytest
from unittest import mock
import importlib

@mock.patch.dict(os.environ, {"BUCKET_BRONZE": "test-bucket", "SNS_TOPIC_ARN": "arn:aws:sns:sa-east-1:123456789012:test-topic"})
def test_lambda_handler_runs():
    script = importlib.import_module("lambda_package.main")
    result = script.lambda_handler({}, {})
    assert isinstance(result, dict)
    assert any(k in result for k in ("status", "message"))