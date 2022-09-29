import boto3
import os
import logging
import random
import string

def get_random_string(length):
    return ''.join(random.choice(string.ascii_letters) for i in range(length))

config = {
'jobDefinition': 'batch-ex-fargate:2', # created based fargate terraform deployment
'jobQueue': 'HighPriorityFargate',
'jobName': 'encrypt_batch_' + get_random_string(8),
'shareIdentifier': 'A1*',
'schedulingPriorityOverride': 0,
'command': ["file_crypto_service.bash", "60"],
'BATCH_FILE_S3_URL': 's3://source-raw-data-bktcode/code/file_crypto_service.bash',
'BATCH_FILE_TYPE': 'script',
'ENV_SOURCE_BUCKET': 'source_bucket', # Fetched from eventbridge events 
'ENV_TARGET_BUCKET': 's3-encrypt-demo-batch',
'ENV_FILE_KEY': 'file_key', # Fetched from eventbridge events 
'ENV_IS_ENCRYPT': 'true',
'ENV_CLEAN_TEMP': 'true',
'ENV_SYMMETRIC_KEY': 's3://source-raw-data-bkt/code/symmetric_keyfile.key' # created using OpenSSL
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
            timeout={ 'attemptDurationSeconds': 3000 }
        )

        log.info(response)
        return {'jobName': job_name, 'environment': environment}
