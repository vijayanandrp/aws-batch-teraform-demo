import boto3
import os
import logging
import random
import string

def get_random_string(length):
    return ''.join(random.choice(string.ascii_letters) for i in range(length))

appname= 's3encdemo05'
version = 1

config = {
'jobDefinition': f'{appname}:{version}', # created based fargate terraform deployment
'jobQueue': f'HighPriorityFargate-{appname}',
'jobName': 'encrypt_batch_' + get_random_string(8),
'shareIdentifier': 'A1*',
'schedulingPriorityOverride': 0,
'command': ["demo_job.sh", "60"],
'BATCH_FILE_S3_URL': 's3://dvtps3-encrypt-demo-raw-bkt/code/file_crypto_service.bash',
'BATCH_FILE_TYPE': 'script',
'ENV_SOURCE_BUCKET': 'source_bucket', # Fetched from eventbridge events 
'ENV_TARGET_BUCKET': 'dvtps3-encrypt-demo-output-bkt',
'ENV_FILE_KEY': 'file_key', # Fetched from eventbridge events 
'ENV_IS_ENCRYPT': 'true',
'ENV_CLEAN_TEMP': 'true',
'ENV_SYMMETRIC_KEY': 's3://dvtps3-encrypt-demo-raw-bkt/code/symmetric_keyfile.key' # created using OpenSSL
}

file_name = os.path.splitext(os.path.basename(__file__))[0]

default_log_args = {
    "level": logging.INFO,
    "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    "datefmt": "%d-%b-%y %H:%M"
}

root = logging.getLogger()
if root.handlers:
    for handler in root.handlers:
        root.removeHandler(handler)


def get_logger(name):
    logging.basicConfig(**default_log_args)
    return logging.getLogger(name)


def lambda_handler(event: dict = None, context: dict = None):
    event =  {'Records': [{'eventVersion': '2.1', 'eventSource': 'aws:s3', 'awsRegion': 'us-east-1', 'eventTime': '2022-12-21T21:13:20.520Z', 'eventName': 'ObjectCreated:Put', 'userIdentity': {'principalId': 'AWS:AROA2EXKW77CUTCCPZC3W:varun.kalvakolu'}, 'requestParameters': {'sourceIPAddress': '136.226.12.176'}, 'responseElements': {'x-amz-request-id': '09AP9CNZ1CT51QBV', 'x-amz-id-2': '3DA9FDAb7GVTAlXnj1WiRJ211I5MgmcZJH4x+gpceHVuWJBE567+ujC8Z+W4tEYUsW019OAqnYxfgaulvDGXsGxjwyBHbQUq'}, 's3': {'s3SchemaVersion': '1.0', 'configurationId': '21ae1ce2-75a0-478f-a5fb-65fc70fc3a55', 'bucket': {'name': 'dvtps3-encrypt-demo-raw-bkt', 'ownerIdentity': {'principalId': 'A1RLH2MXWG4MH9'}, 'arn': 'arn:aws:s3:::dvtps3-encrypt-demo-raw-bkt'}, 'object': {'key': 'GDS_CareSource_202104_MA198_prof_v2.txt', 'size': 2438674, 'eTag': '65052d3c981897568096d01101447708', 'versionId': 'pRWljKEnFqVwFAx9ye.zKyskjlz8VgBp', 'sequencer': '0063A376F05C2EA16E'}}}]}
    client = boto3.client('batch')
    log = get_logger(f"{file_name}.{lambda_handler.__name__}")
    log.info('=' * 30 + " Init " + '=' * 30)
    job_name = config['jobName']
    log.info(f"job_name - {job_name}")
    log.info(f"event - {event}")
    log.info(f"context - {context}")
    records = event.get("Records", None)
    if not records:
        log.info(f"[-] No Records found in the events - {event}")
        return None

    new_files = [{'bucket': record["s3"]["bucket"]["name"],
                  'key': record['s3']['object']['key'],
                  'size': record['s3']['object']['size']}
                 for record in records
                 if record.get("s3")]

    for new_file in new_files:
        log.info(f'New File - {new_file}')
        source_bucket = new_file['bucket']
        file_key = new_file['key']
        environment = [
            {
                'name': 'BATCH_FILE_S3_URL',
                'value': config['BATCH_FILE_S3_URL']
            },
            {
                'name': 'BATCH_FILE_TYPE',
                'value': config['BATCH_FILE_TYPE']
            },
            {
                'name': 'ENV_SOURCE_BUCKET',
                'value': source_bucket
            },
            {
                'name': 'ENV_TARGET_BUCKET',
                'value': config['ENV_TARGET_BUCKET']
            },
            {
                'name': 'ENV_FILE_KEY',
                'value': file_key
            },
            {
                'name': 'ENV_IS_ENCRYPT',
                'value': config['ENV_IS_ENCRYPT']
            },
            {
                'name': 'ENV_CLEAN_TEMP',
                'value': config['ENV_CLEAN_TEMP']
            },
            {
                'name': 'ENV_SYMMETRIC_KEY',
                'value': config['ENV_SYMMETRIC_KEY']
            }
        ]
        
        log.info(f"environment - {environment}")
        response = client.submit_job(
            jobDefinition=config['jobDefinition'], # created based fargate terraform deployment
            jobQueue=config['jobQueue'],
            jobName=config['jobName'],
            shareIdentifier=config['shareIdentifier'],
            schedulingPriorityOverride=config['schedulingPriorityOverride'],
            containerOverrides={
                'command': config['command'],
                'environment': environment },
            timeout={ 'attemptDurationSeconds': 7200 }
        )

        log.info(response)
        return {'jobName': job_name, 'config': config}
