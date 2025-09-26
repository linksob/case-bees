import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from awsgluedq.transforms import EvaluateDataQuality
import pyspark.sql.functions as F
from datetime import datetime
import boto3
import logging
import pyspark.sql.functions as F


def init_globals():
    global args, sc, glueContext, spark, job, logger
    args = getResolvedOptions(sys.argv, [
        "JOB_NAME",
        "GOLD_PATH",
        "DATABASE_NAME",
        "DATABASE_NAME_SILVER",
        "TABLE_NAME",
        "TABLE_NAME_SILVER",
        "SNS_TOPIC_ARN"
    ])
    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

def alert_sns(message):
    try:
        topic_arn = args["SNS_TOPIC_ARN"]
    except Exception:
        topic_arn = None
    sns = boto3.client("sns", region_name="sa-east-1")
    if topic_arn:
        sns.publish(
            TopicArn=topic_arn,
            Message=message,
            Subject=f'Job Failed - job-silver_to_gold - {datetime.now().isoformat()}'
        )

def read_silver():
    dyf = glueContext.create_dynamic_frame.from_catalog(
        database=args["DATABASE_NAME_SILVER"],
        table_name=args["TABLE_NAME_SILVER"],
        transformation_ctx="read_silver")
    
    df = dyf.toDF()
    df.show(5)
    return df


def data_transformation(df):
    agg_df = df.groupBy(
        "brewery_type",
        "state_province",
        "city"
                 ).agg(
        F.count("*").alias("brewery_count")
        )
    
    agg_df = agg_df.withColumn("transaction_date", F.date_format(F.current_date(), "yyyy-MM-dd"))

    return agg_df


def data_quality(dyf):
    logger.info("Starting data quality evaluation")
    ruleset = """
        Rules = [
            IsPrimaryKey "brewery_type" "state_province" "city",
            IsComplete "brewery_type",
            IsComplete "state_province",
            IsComplete "city"
        ]
    """
    
    dq_results = EvaluateDataQuality.apply(
        frame=dyf,
        ruleset=ruleset,
        publishing_options={
            "dataQualityEvaluationContext": "job-silver_to_gold",
            "enableDataQualityMetrics": True
        }
    )
    dq_df = dq_results.toDF()
    dq_df.show(truncate=False)
    failed = dq_df.filter(dq_df["Outcome"] != "Passed").count()
    if failed > 0:
        alert_sns(f"Data Quality Check Failed:\n{failed}")
        raise Exception("Falha na checagem de qualidade dos dados!")
    logger.info("Data quality check passed")


def upload(dyf):
    logger.info("Starting upload to Gold layer")
    glueContext.write_dynamic_frame.from_catalog(
        frame=dyf,
        database=args["DATABASE_NAME"],
        table_name=args["TABLE_NAME"],
        additional_options={
            "partitionKeys": ["transaction_date","state_province"],
            "updateBehavior": "UPDATE_IN_DATABASE"
        },
        transformation_ctx="datasink"
    )


def main():
    try:
        init_globals() 
        silver_df = read_silver()
        gold_df = data_transformation(silver_df)
        gold_df.show(5)
        dyf = DynamicFrame.fromDF(gold_df, glueContext, "dynamic_frame")
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