import json
import boto3
import os
import time

def lambda_handler(event, context):
    database = os.environ.get('ATHENA_DB', 'db_bees_gold')
    table = os.environ.get('ATHENA_TABLE', 'tb_bees_breweries_gold')
    output = os.environ.get('ATHENA_OUTPUT', 's3://bees-breweries-athena-query-results/')
    workgroup = os.environ.get('ATHENA_WORKGROUP', 'primary')

    params = event.get('queryStringParameters') or {}
    date = params.get('date')
    city = params.get('city')

    filters = []
    if date:
        filters.append(f"transaction_date = '{date}'")
    if city:
        filters.append(f"city = '{city}'")
    where = f"WHERE {' AND '.join(filters)}" if filters else ''

    query = f"SELECT * FROM {table} {where} LIMIT 100;"

    athena = boto3.client('athena')
    try:
        print(f"Query: {query}")
        response = athena.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': database},
            ResultConfiguration={'OutputLocation': output},
            WorkGroup=workgroup
        )
        exec_id = response['QueryExecutionId']

        for _ in range(30):
            status = athena.get_query_execution(QueryExecutionId=exec_id)
            state = status['QueryExecution']['Status']['State']
            if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
                print(f"QueryExecution status: {state}")
                if state != 'SUCCEEDED':
                    print(f"QueryExecution error: {status['QueryExecution']['Status'].get('StateChangeReason', '')}")
                break
            time.sleep(1)
        if state != 'SUCCEEDED':
            return {'statusCode': 500, 'body': json.dumps({'error': 'Query failed'})}

        result = athena.get_query_results(QueryExecutionId=exec_id)
        columns = [col['Label'] for col in result['ResultSet']['ResultSetMetadata']['ColumnInfo']]
        rows = []
        for row in result['ResultSet']['Rows'][1:]:
            values = []
            for v in row['Data']:
                values.append(v.get('VarCharValue', None))
            row_dict = dict(zip(columns, values))
            rows.append(row_dict)
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(rows, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Lambda error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
