import boto3

client = boto3.client('batch')

def lambda_handler(event, context):
    print("Hello from app1!")
    
    response = client.submit_job(
    jobDefinition='batch-ex-fargate:2',
    jobName='demo_lambda_batch_1',
    jobQueue='HighPriorityFargate',
    shareIdentifier='A1*',
    schedulingPriorityOverride=0,
    containerOverrides={
        'vcpus': 1,
        'memory': 2048,
        'environment': [
            {
                'name': 'BATCH_FILE_S3_URL',
                'value': 's3://s3-encrypt-demo-batch/file_crypto_service.bash',
            },
            {
                'name': 'ENV_SOURCE_BUCKET',
                'value': 's3-encrypt-demo-batch',
            },
            {
                'name': 'ENV_TARGET_BUCKET',
                'value': 's3-encrypt-demo-batch',
            },
            {
                'name': 'ENV_FILE_KEY',
                'value': 'testData.csv',
            },
            {
                'name': 'ENV_IS_ENCRYPT',
                'value': 'true',
            },
            {
                'name': 'ENV_CLEAN_TEMP',
                'value': 'true',
            },
            {
                'name': 'ENV_FILE_KEY',
                'value': 's3://s3-encrypt-demo-batch/symmetric_keyfile.key',
            }
        ]
        },
       timeout={
        'attemptDurationSeconds': 3000
    },
    )

    print(response)
    return event
