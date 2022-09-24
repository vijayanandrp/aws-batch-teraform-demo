#!/bin/bash
date
echo "Args: $@"
env
echo "This is my simple test job!."
echo "jobId: $AWS_BATCH_JOB_ID"
echo "jobQueue: $AWS_BATCH_JQ_NAME"
echo "computeEnvironment: $AWS_BATCH_CE_NAME"
echo "Batch File S3 URL: $BATCH_FILE_S3_URL"
echo "Batch File Type: $BATCH_FILE_TYPE"
sleep $1
date
echo "bye bye!!"
