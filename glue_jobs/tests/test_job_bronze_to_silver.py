import sys
from unittest.mock import MagicMock
import pytest
from unittest.mock import patch, MagicMock

# Mock awsglue
sys.modules['awsglue'] = MagicMock()
sys.modules['awsglue.transforms'] = MagicMock()
sys.modules['awsglue.utils'] = MagicMock()
sys.modules['awsglue.context'] = MagicMock()
sys.modules['awsglue.job'] = MagicMock()
sys.modules['awsglue.dynamicframe'] = MagicMock()
sys.modules['awsgluedq.transforms'] = MagicMock()
sys.modules['pyspark'] = MagicMock()
sys.modules['pyspark.context'] = MagicMock()
sys.modules['pyspark.sql'] = MagicMock()
sys.modules['pyspark.sql.functions'] = MagicMock()
sys.modules['pyspark.sql.types'] = MagicMock()
import app.job_bronze_to_silver as script


@patch('app.job_bronze_to_silver.boto3.client')
@patch('app.job_bronze_to_silver.upload')
@patch('app.job_bronze_to_silver.data_quality')
@patch('app.job_bronze_to_silver.DynamicFrame')
@patch('app.job_bronze_to_silver.data_transformation')
@patch('app.job_bronze_to_silver.read_bronze')
@patch('app.job_bronze_to_silver.init_globals')
@patch('app.job_bronze_to_silver.job', create=True)
def test_main_calls(mock_job, mock_init_globals, mock_read_bronze, mock_data_transformation, mock_DynamicFrame, mock_data_quality, mock_upload, mock_boto3_client):

    fake_args = {
        "JOB_NAME": "test_job",
        "BRONZE_PATH": "/tmp/bronze/",
        "SILVER_PATH": "/tmp/silver/",
        "DATABASE_NAME": "test_db",
        "TABLE_NAME": "test_table",
        "SNS_TOPIC_ARN": "arn:aws:sns:sa-east-1:123456789012:test-topic"
    }
    script.args = fake_args
    script.logger = MagicMock(name='logger')
    script.glueContext = MagicMock(name='glueContext')

    mock_read_bronze.return_value = MagicMock(name='df')
    mock_data_transformation.return_value = MagicMock(name='df_transformed')
    mock_DynamicFrame.fromDF.return_value = MagicMock(name='dyf')

    script.main()

    mock_init_globals.assert_called_once()
    mock_read_bronze.assert_called_once()
    mock_data_transformation.assert_called_once()
    mock_DynamicFrame.fromDF.assert_called_once()
    mock_data_quality.assert_called_once()
    mock_upload.assert_called_once()
    mock_job.commit.assert_called_once()