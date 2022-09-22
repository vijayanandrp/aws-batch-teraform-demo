# ENVIRONMENTAL VARIABLES
# BUCKETS
SOURCE_BUCKET=$ENV_SOURCE_BUCKET
TARGET_BUCKET=$ENV_TARGET_BUCKET
# SYMMETRIC KEY FOR ENCRYPT/DECRYPT
KEY_URL=s3://${ENV_SYMMETRIC_KEY}
# S3 FILE KEY
FILE_KEY=$ENV_FILE_KEY
# FLAG TO RUN ENCRYPT
is_encrypt=$ENV_IS_ENCRYPT


SYMMETRIC_FILE="$(basename $KEY_URL)"
COMPRESS_FILE_KEY=${FILE_KEY}.gz
ENC_FILE_KEY=${COMPRESS_FILE_KEY}.enc

CORES=$(nproc --all)
flag=true
DOWNLOAD_DIR=~
TMP_DIR=tmp_encrypt

if ($is_encrypt && $flag); then
    echo   ############# Encrypt Starts ################### 
    echo "FILE_KEY: $FILE_KEY";
    echo "SOURCE_BUCKET: $SOURCE_BUCKET";
    echo "TARGET_BUCKET: $TARGET_BUCKET";
    echo "KEY_URL: $KEY_URL";
    echo "SYMMETRIC_FILE: $SYMMETRIC_FILE";
    echo "CORES: $CORES";

    DEC_FILE_KEY=decrypted_${FILE_KEY}

    echo [*] Moving to User Home Directory '>>>'  ${TMP_DIR}
    cd  ${DOWNLOAD_DIR}
    mkdir -p ${TMP_DIR}
    cd ${TMP_DIR}
    pwd
    date; ls -larthi;

    echo [*] Download Symmetric Key File ${KEY_URL}... 
    rm -rf ${SYMMETRIC_FILE}
    aws s3 cp ${KEY_URL} .
    date; ls -larthi;
    echo $'\n'


    echo [*] Download File ${FILE_KEY} from S3 Bucket ${SOURCE_BUCKET} 
    rm -rf ${FILE_KEY}
    aws s3 ls s3://${SOURCE_BUCKET}/${FILE_KEY}
    aws s3 cp s3://${SOURCE_BUCKET}/${FILE_KEY}  .  --no-progress
    echo "Hash sha1sum - $(sha1sum ${FILE_KEY})"
    date; ls -larthi;
    echo $'\n'

    echo [*] Compressing file ${FILE_KEY} '>>>' ${COMPRESS_FILE_KEY}
    rm -rf ${COMPRESS_FILE_KEY}
    pigz -9 -p${CORES}  ${FILE_KEY}
    date; ls -larthi;
    echo $'\n'

    echo [*] Encrypting file ${COMPRESS_FILE_KEY} '>>>' ${ENC_FILE_KEY}
    rm -rf ${ENC_FILE_KEY}
    openssl enc -in ${COMPRESS_FILE_KEY} -out ${ENC_FILE_KEY} -e -aes256 -k ${SYMMETRIC_FILE}

    echo [*] Upload Encrypted File ${ENC_FILE_KEY} to S3 Bucket s3://${TARGET_BUCKET}/${ENC_FILE_KEY}
    aws s3 cp  ${ENC_FILE_KEY}  s3://${TARGET_BUCKET}/${ENC_FILE_KEY} --no-progress
    aws s3 ls s3://${TARGET_BUCKET}/${ENC_FILE_KEY}
    date; ls -larthi;
    echo $'\n'
    echo   ############# Encrypt Ends ###################
else
    echo   ############# Decrypt Starts ################### 
    echo "FILE_KEY: $FILE_KEY";
    echo "SOURCE_BUCKET: $SOURCE_BUCKET";
    echo "TARGET_BUCKET: $TARGET_BUCKET";
    echo "KEY_URL: $KEY_URL";
    echo "SYMMETRIC_FILE: $SYMMETRIC_FILE";
    echo "CORES: $CORES";

    DEC_FILE_KEY=decrypted_${FILE_KEY}

    echo [*] Moving to User Home Directory '>>>'  ${TMP_DIR}
    cd  ${DOWNLOAD_DIR}
    mkdir -p ${TMP_DIR}
    cd ${TMP_DIR}
    pwd
    date; ls -larthi;

    echo [*] Download Symmetric Key File ${KEY_URL}... 
    rm -rf ${SYMMETRIC_FILE}
    aws s3 cp ${KEY_URL} .
    date; ls -larthi;
    echo $'\n'

    echo [*] Download Encrypted File ${ENC_FILE_KEY} from S3 Bucket ${SOURCE_BUCKET} 
    rm -rf ${ENC_FILE_KEY}
    aws s3 cp s3://${SOURCE_BUCKET}/${ENC_FILE_KEY}  .  --no-progress
    date; ls -larthi;
    echo $'\n'
    
    echo [*] Decrypting file ${ENC_FILE_KEY} '>>>' ${COMPRESS_FILE_KEY}
    rm -rf ${COMPRESS_FILE_KEY}
    openssl enc -in ${ENC_FILE_KEY} -out ${COMPRESS_FILE_KEY} -d -aes256 -k ${SYMMETRIC_FILE}
    date; ls -larthi;
    echo $'\n'

    echo [*] Decompressing file ${COMPRESS_FILE_KEY} '>>>' ${FILE_KEY}
    rm -rf ${FILE_KEY}
    pigz -d ${COMPRESS_FILE_KEY}
    date; ls -larthi;
    echo $'\n'

    echo [*] Upload File ${FILE_KEY} '>>>'  S3 Bucket  s3://${TARGET_BUCKET}/${DEC_FILE_KEY}
    echo "Hash sha1sum - $(sha1sum ${FILE_KEY})"
    aws s3 cp  ${FILE_KEY}  s3://${TARGET_BUCKET}/${DEC_FILE_KEY}  --no-progress
    aws s3 ls  s3://${TARGET_BUCKET}/${DEC_FILE_KEY}
    date; ls -larthi;
    echo $'\n'
    echo   ############# Decrypt Ends ###################  $'\n'
fi

if ($ENV_CLEAN_TEMP && $flag); then
    echo [*] Deleting all files & remove dir ...
    cd ..;
    rm -rf ${TMP_DIR};
fi
pwd
date; ls -larthi;

