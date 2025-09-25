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
            break
        
        if not data:
            break

        breweries.extend(data)
        logger.info(f"Fetched page {page} with {len(data)} records.")

        if len(data) < PER_PAGE:
            break

        page += 1

    now = datetime.now()
    key = f"bronze/year={now:%Y}/month={now:%m}/day={now:%d}/breweries_{now:%Y%m%d_%H%M%S}.json"

    try:
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=json.dumps(breweries),
            ContentType="application/json"
        )
    except Exception as e:
        logger.error(f"Error uploading to S3: {e}")
        return {"message": str(e)}

    return {"status": "ok", "records": len(breweries), "s3_key": key}