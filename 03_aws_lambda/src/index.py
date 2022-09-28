import boto3

client = boto3.client('batch')

def get_random_string(length):
    # With combination of lower and upper case
    result_str = ''.join(random.choice(string.ascii_letters) for i in range(length))
    # print random string
    print(result_str)

def lambda_handler(event, context):
    job_name='demo_lambda_encrypt_batch_' + get_random_string(8)
    print('job_name', job_name)
    
    
    response = client.submit_job(
    jobDefinition='batch-ex-fargate:2',
    jobQueue='HighPriorityFargate',
    jobName=job_name,
    shareIdentifier='A1*',
    schedulingPriorityOverride=0,
    containerOverrides={
        'command': ["file_crypto_service.bash", "60"],
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
    return {'jobName': job_name}
