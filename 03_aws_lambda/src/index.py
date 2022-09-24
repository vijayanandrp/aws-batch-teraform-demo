import boto3

client = boto3.client('batch')

def lambda_handler(event, context):
    print("Hello from app1!")
    
    response = client.submit_job(
    jobDefinition='batch-ex-fargate:2',
    jobName='demo_lambda_batch_2',
    jobQueue='HighPriorityFargate',
    shareIdentifier='A1*',
    schedulingPriorityOverride=0,
    containerOverrides={
        'command': ["file_crypto_service.bash","60"],
        'environment': [
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
                'value': 's3-encrypt-demo-batch'
            },
            {
                'name': 'ENV_TARGET_BUCKET',
                'value': 's3-encrypt-demo-batch'
            },
            {
                'name': 'ENV_FILE_KEY',
                'value': 'testData.csv'
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
        },
       timeout={
        'attemptDurationSeconds': 3000
    },
    )

    print(response)
    return event
