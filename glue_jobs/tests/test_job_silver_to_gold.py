import sys
from unittest.mock import MagicMock
import pytest
from unittest.mock import patch, MagicMock

# Mock awsglue and pyspark modules
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
import app.job_silver_to_gold as script


@patch('app.job_silver_to_gold.boto3.client')
@patch('app.job_silver_to_gold.upload')
@patch('app.job_silver_to_gold.data_quality')
@patch('app.job_silver_to_gold.DynamicFrame')
@patch('app.job_silver_to_gold.data_transformation')
@patch('app.job_silver_to_gold.read_silver')
@patch('app.job_silver_to_gold.init_globals')
@patch('app.job_silver_to_gold.job', create=True)
def test_main_calls(mock_job, mock_init_globals, mock_read_silver, mock_data_transformation, mock_DynamicFrame, mock_data_quality, mock_upload, mock_boto3_client):
    fake_args = {
        "JOB_NAME": "test_job",
        "GOLD_PATH": "/tmp/gold/",
        "DATABASE_NAME": "test_db",
        "DATABASE_NAME_SILVER": "test_db_silver",
        "TABLE_NAME": "test_table",
        "TABLE_NAME_SILVER": "test_table_silver",
        "SNS_TOPIC_ARN": "arn:aws:sns:sa-east-1:123456789012:test-topic"
    }
    script.args = fake_args
    script.glueContext = MagicMock(name='glueContext')
    script.logger = MagicMock(name='logger')

    mock_read_silver.return_value = MagicMock(name='df')
    mock_data_transformation.return_value = MagicMock(name='df_transformed')
    mock_DynamicFrame.fromDF.return_value = MagicMock(name='dyf')

    script.main()

    mock_init_globals.assert_called_once()
    mock_read_silver.assert_called_once()
    mock_data_transformation.assert_called_once()
    mock_DynamicFrame.fromDF.assert_called_once()
    mock_data_quality.assert_called_once()
    mock_upload.assert_called_once()
    mock_job.commit.assert_called_once()
