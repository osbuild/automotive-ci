#!/bin/bash
set -eo pipefail

ARCH=$(arch)
UUID=${UUID:-local}
IMAGE_KEY="osbuild-${ARCH}-${UUID}"
DOWNLOAD_DIRECTORY="/var/tmp/"
S3_BUCKET_NAME="fedora-testing-farm-image-import"
AWS_CLI="aws"
AWS_REGION="us-east-2"

echo "[+] Install dependencies"
dnf install -y awscli

echo "[+] Configure AWS settings"
$AWS_CLI configure set default.region "$AWS_REGION"
$AWS_CLI configure set default.output json

if [ ! -r "${DOWNLOAD_DIRECTORY}/${IMAGE_KEY}.img" ]; then
    echo "Error: the file ${DOWNLOAD_DIRECTORY}/${IMAGE_KEY}.img doesn't exist"
    exit 1
fi
echo "[+] Uploading the image to 's3://${S3_BUCKET_NAME}/${IMAGE_KEY}.img"
$AWS_CLI s3 cp ${DOWNLOAD_DIRECTORY}/${IMAGE_KEY}.img s3://${S3_BUCKET_NAME} --only-show-errors

