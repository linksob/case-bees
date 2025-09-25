import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from awsglue.data_quality import EvaluateDataQuality
import pyspark.sql.functions as F
from unidecode import unidecode
from pyspark.sql.types import StringType
from datetime import datetime
import boto3
import logging



def init_globals():
    global args, sc, glueContext, spark, job, logger
    args = getResolvedOptions(sys.argv, [
        "JOB_NAME",
        "BRONZE_PATH",
        "SILVER_PATH",
        "DATABASE_NAME",
        "TABLE_NAME"
    ])
    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    spark.conf.set("spark.sql.shuffle.partitions", "2")
    spark.conf.set("spark.default.parallelism", "2")
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)



def read_bronze():
    bronze_path = args["BRONZE_PATH"]
    df = spark.read.json(bronze_path)
    df.show(5)
    return df

@F.udf(returnType=StringType())
def normalize_str(s):
    if s is not None:
        return unidecode(s)
    return s

def data_manipulation(df):
    df = df.select(
        "id",
        "name",
        "brewery_type",
        "address_1",
        "city",
        "state_province",
        "country",
        "longitude",
        "latitude",
        "phone",
        "website_url"
    )  
    df = df.withColumn("transaction_date", F.date_format(F.current_date(), "yyyy-MM-dd"))
    df = df.withColumn("longitude", df["longitude"].cast("double")) \
       .withColumn("latitude", df["latitude"].cast("double")) \
       .withColumn("phone", F.regexp_replace("phone", "-", "")) \
       .withColumn("website_url", F.lower(F.col("website_url"))) \
       .withColumn("city", F.lower(normalize_str(F.col("city")))) \
       .withColumn("state_province", F.lower(normalize_str(F.col("state_province"))))
       
    return df

def alert_sns( message):
    sns = boto3.client("sns", region_name="sa-east-1")
    sns.publish(
        topic_arn="arn:aws:sns:us-east-1:418295684947:bronze_to_silver_dq",
        message=message,
        subject=f'Job Failed - job-bronze_to_silver - {datetime.now().isoformat()}'
    )


def data_quality(dyf):
    logger.info("Starting data quality evaluation")
    ruleset = """
        Rules = [
            IsPrimaryKey "id",
            IsComplete "name",
            ColumnValues "longitude" BETWEEN (-180, 180),
            ColumnValues "latitude"  BETWEEN (-90, 90),
            ColumnLength "phone" BETWEEN (9, 11)
        ]
    """
    dq_results = glueContext.EvaluateDataQuality(
        glueContext=glueContext,
        frame=dyf,
        ruleset=ruleset,
        publishing_options={
            "dataQualityEvaluationContext": "bronze_to_silver_dq",
            "enableDataQualityMetrics": True
        }
    )
    dq_results.printResults()
    if dq_results.state != "PASS":
        alert_sns(f"Data Quality Check Failed:\n{dq_results.toJSON()}"
    )
        raise Exception("Falha na checagem de qualidade dos dados!")
    
def upload(df):
    logger.info("Starting upload to Silver layer")
    dynamic_frame = DynamicFrame.fromDF(df, glueContext, "dynamic_frame")
    glueContext.write_dynamic_frame.from_catalog(
        frame=dynamic_frame,
        database=args["DATABASE_NAME"],
        table_name=args["TABLE_NAME"],
        additional_options={"partitionKeys": ["transaction_date", "state_province", "city"]},
        transformation_ctx="datasink"
    )

def main():
    try:
        init_globals()
        df = read_bronze()
        df = data_manipulation(df)
        data_quality(df)
        upload(df)
        job.commit()
    except Exception as e:
        alert_sns(
            message=str(e)
        )
        raise e
    logger.info("Job FINISHED")
if __name__ == "__main__":
    main()