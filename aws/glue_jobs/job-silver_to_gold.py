import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
import pyspark.sql.functions as F


def init_globals():
    global args, sc, glueContext, spark, job
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
    job = Job(glueContext)
    job.init(args["JOB_NAME"], args)


def read_silver():
    dyf = glueContext.create_dynamic_frame.from_catalog(
        database=args["DATABASE_NAME"],
        table_name=args["TABLE_NAME"],
        transformation_ctx="read_silver")
    
    df = dyf.toDF()
    return df


def data_transformation(df):
    agg_df = df.groupBy(
        "brewery_type",
        "state_province",
        "city"
                 ).agg(
        F.count("*").alias("brewery_count")
        )
    return agg_df

def upload(df):
    dyf = DynamicFrame.fromDF(df, glueContext, "upload")
    glueContext.write_dynamic_frame.from_options(
        frame=dyf,
        connection_type="s3",
        connection_options={
            "path": args["SILVER_PATH"],
            "partitionKeys": ["state_province"]
        },
        format="parquet",
        transformation_ctx="upload"
    )

def main():
    init_globals()
    silver_df = read_silver()
    gold_df = data_transformation(silver_df)
    upload(gold_df)
    job.commit()

if __name__ == "__main__":
    main()