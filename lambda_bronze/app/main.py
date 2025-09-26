import json
import os
import boto3
import requests
from datetime import datetime
import logging


logging.basicConfig(level=logging.INFO) 
logger = logging.getLogger(__name__)

S3_BUCKET = os.environ["BUCKET_BRONZE"]
API_URL   = "https://api.openbrewerydb.org/v1/breweries"

s3 = boto3.client("s3")

def alert_sns(message):
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN")
    if not sns_topic_arn:
        logger.error("SNS_TOPIC_ARN environment variable not set.")
        return
    try:
        sns = boto3.client("sns")
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject="ERROR - Lambda BEES-breweries-bronze",
            Message=message
        )
        logger.info(f"SNS alert sent: ERROR - Lambda BEES-breweries-bronze - {datetime.now().isoformat()}")
    except Exception as e:
        logger.error(f"Error sending SNS alert: {e}")


def lambda_handler(event, context):
    PER_PAGE = 200
    breweries = []
    page = 1

    while True:
        url = f"{API_URL}?per_page={PER_PAGE}&page={page}"
        try:
            resp = requests.get(url, timeout=10)
            resp.raise_for_status()
            data = resp.json()
        except requests.RequestException as e:
            logger.error(f"Error fetching API page {page}: {e}")
            alert_sns(
                message=f"Error in search page {page}: {e}"
            )
            break
        
        if not data:
            break

        breweries.extend(data)
        logger.info(f"Fetched page {page} with {len(data)} records.")

        if len(data) < PER_PAGE:
            break

        page += 1

    now = datetime.now()
    transaction_date = now.strftime("%Y%m%d")
    
    for b in breweries:
        b["transaction_date"] = transaction_date
    key = f"bronze/transaction_date={transaction_date}/breweries_{now:%Y%m%d_%H%M%S}.json"

    body = "\n".join(json.dumps(b) for b in breweries)
    try:
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=body,
            ContentType="application/json"
        )
    except Exception as e:
        logger.error(f"Error uploading to S3: {e}")
        alert_sns(
            message=f"Error when saving file on {key} in bucket {S3_BUCKET}: {e}"
        )
        return {"message": str(e)}

    return {"status": "ok", "records": len(breweries), "s3_key": key}