import boto3
import os
import logging
import random
import string

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


def get_random_string(length):
    return ''.join(random.choice(string.ascii_letters) for i in range(length))


def lambda_handler(event: dict = None, context: dict = None):
    client = boto3.client('batch')
    log = get_logger(f"{file_name}.{lambda_handler.__name__}")
    log.info('=' * 30 + " Init " + '=' * 30)
    job_name = 'demo_lambda_encrypt_batch_' + get_random_string(8)
    log.info(f"job_name - {job_name}")
    log.info(f"event - {event}")
    log.info(f"context - {context}")
    records = event.get("Records", None)
    if not records:
        log.info(f"[-] No Records found in the events - {event}")
        return None

    new_files = [{'bucket': record["s3"]["bucket"]["name"],
                  'key': record['s3']['object']['key'],  # m5/insights/new_user_report/date=2022-05-22
                  'size': record['s3']['object']['size']}
                 for record in records
                 if record.get("s3")]

    for new_file in new_files:
        log.info(f'New File - {new_file}')
        bucket = new_file['bucket']
        file_key = new_file['key']
        environment = [
            {
                'name': 'BATCH_FILE_S3_URL',
                'value': 's3://s3-encrypt-demo-batch/file_crypto_service.bash'
            },
            {
                'name': 'BATCH_FILE_TYPE',
                'value': 'script'
            },
            {
                'name': 'ENV_SOURCE_BUCKET',
                'value': bucket
            },
            {
                'name': 'ENV_TARGET_BUCKET',
                'value': 's3-encrypt-demo-batch'
            },
            {
                'name': 'ENV_FILE_KEY',
                'value': file_key
            },
            {
                'name': 'ENV_IS_ENCRYPT',
                'value': 'true'
            },
            {
                'name': 'ENV_CLEAN_TEMP',
                'value': 'true'
            },
            {
                'name': 'ENV_SYMMETRIC_KEY',
                'value': 's3://s3-encrypt-demo-batch/symmetric_keyfile.key'
            }
        ]
        log.info(f"environment - {environment}")

        response = client.submit_job(
            jobDefinition='batch-ex-fargate:2',
            jobQueue='HighPriorityFargate',
            jobName=job_name,
            shareIdentifier='A1*',
            schedulingPriorityOverride=0,
            containerOverrides={
                'command': ["file_crypto_service.bash", "60"],
                'environment': environment
            },
            timeout={
                'attemptDurationSeconds': 3000
            },
        )

        log.info(response)
        return {'jobName': job_name, 'environment': environment}
