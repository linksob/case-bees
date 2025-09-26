import sys
import os
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from awsgluedq.transforms import EvaluateDataQuality
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
        "TABLE_NAME",
        "SNS_TOPIC_ARN"
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


def alert_sns( message):
    sns = boto3.client("sns", region_name="sa-east-1")
    sns.publish(
        TopicArn=args["SNS_TOPIC_ARN"],
        Message=message,
        Subject=f'Job Failed - job-bronze_to_silver - {datetime.now().isoformat()}'
    )


def read_bronze():
    today = datetime.now().strftime("%Y%m%d")
    bronze_path = args['BRONZE_PATH'] + today
    df = spark.read.json(bronze_path)
    df.show(5)
    return df

@F.udf(returnType=StringType())
def normalize_str(s):
    if s is not None:
        return unidecode(s)
    return s

def data_transformation(df):
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
    df = (
            df.withColumn("transaction_date", F.date_format(F.current_date(), "yyyy-MM-dd"))
            .withColumn("longitude", df["longitude"].cast("double"))
            .withColumn("latitude", df["latitude"].cast("double"))
            .withColumn("phone", F.regexp_replace("phone", "-", ""))
            .withColumn("website_url", F.lower(F.col("website_url")))
            .withColumn("city", F.lower(normalize_str(F.col("city"))))
            .withColumn("state_province", F.lower(normalize_str(F.col("state_province"))))
            .filter((F.col("longitude") >= -180) & (F.col("longitude") <= 180))
            .filter((F.col("latitude") >= -90) & (F.col("latitude") <= 90))
            .filter(F.col("phone").isNotNull())
            .filter((F.length(F.col("phone")) >= 8) & (F.length(F.col("phone")) <= 16))
        )
    
    df = df.dropDuplicates(["id"])
    return df


def data_quality(dyf):
    logger.info("Starting data quality evaluation")

    ruleset = """
        Rules = [
            IsPrimaryKey "id",
            IsComplete "name",
            ColumnValues "longitude" between -180 and 180,
            ColumnValues "latitude" between -90 and 90,
            ColumnLength "phone" between 7 and 17
        ]
        """

    dq_results = EvaluateDataQuality.apply(
        frame=dyf,
        ruleset=ruleset,
        publishing_options={
            "dataQualityEvaluationContext": "job-bronze_to_silver",
            "enableDataQualityMetrics": True
        }
    )

    dq_df = dq_results.toDF()
    dq_df.show(truncate=False)

    # Verify if any rule failed
    failed = dq_df.filter(dq_df["Outcome"] != "Passed").count()
    df_failed = dq_df.filter(dq_df["Outcome"] != "Passed")
    if failed > 0:
        alert_sns(f"Data Quality Check Failed:\n{df_failed.collect()}")
        raise Exception("Data quality check failed!")

    logger.info("Data quality check passed")
    
def upload(dyf):
    logger.info("Starting upload to Silver layer")
    
    glueContext.write_dynamic_frame.from_catalog(
        frame=dyf,
        database=args["DATABASE_NAME"], 
        table_name=args["TABLE_NAME"],        
        additional_options={
            "partitionKeys": ["transaction_date", "state_province", "city"],
            "updateBehavior": "UPDATE_IN_DATABASE"
        },
        format="glueparquet",
        format_options={"compression": "snappy"},
        transformation_ctx="datasink"
    )


def main():
    try:
        init_globals()
        df = read_bronze()
        df = data_transformation(df)
        dyf = DynamicFrame.fromDF(df, glueContext, "dynamic_frame")
        data_quality(dyf)
        upload(dyf)
        job.commit()
    except Exception as e:
        alert_sns(
            message=str(e)
        )
        raise e
    logger.info("Job FINISHED")
if __name__ == "__main__":
    main()