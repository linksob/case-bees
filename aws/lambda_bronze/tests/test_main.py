import json
import pytest
from unittest.mock import patch, MagicMock
from lambda_bronze.main import lambda_handler

# Dados simulados da API
fake_api_response = [{"id":1,"name":"Brewery A","brewery_type":"micro"}]

# -----------------------
# Teste de sucesso
# -----------------------
@patch("lambda_bronze.main.boto3.client")
@patch("lambda_bronze.main.requests.get")
def test_lambda_success(mock_requests_get, mock_boto_client):
    # Configura mock da API
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = fake_api_response
    mock_requests_get.return_value = mock_resp

    # Configura mock do S3
    mock_s3 = MagicMock()
    mock_boto_client.return_value = mock_s3

    # Define variável de ambiente
    import os
    os.environ["BUCKET_BRONZE"] = "test-bucket"

    # Chama Lambda
    result = lambda_handler({}, {})

    # Testa retorno
    assert result["status"] == "ok"
    assert result["records"] == len(fake_api_response)
    assert "s3_key" in result

    # Testa se boto3 put_object foi chamado
    mock_s3.put_object.assert_called_once()
    args, kwargs = mock_s3.put_object.call_args
    assert kwargs["Bucket"] == "test-bucket"
    uploaded_body = json.loads(kwargs["Body"])
    assert uploaded_body == fake_api_response

# -----------------------
# Teste de falha da API
# -----------------------
@patch("lambda_bronze.main.boto3.client")
@patch("lambda_bronze.main.requests.get")
def test_lambda_api_failure(mock_requests_get, mock_boto_client):
    # Simula erro da API
    mock_resp = MagicMock()
    mock_resp.raise_for_status.side_effect = Exception("API error")
    mock_requests_get.return_value = mock_resp

    # S3 não será chamado
    mock_s3 = MagicMock()
    mock_boto_client.return_value = mock_s3

    result = lambda_handler({}, {})

    assert result["status"] == "error"
    assert "API error" in result["message"]
    mock_s3.put_object.assert_not_called()
