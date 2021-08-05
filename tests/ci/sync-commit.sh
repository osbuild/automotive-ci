#!/bin/bash
set -eo pipefail

ACTION=${1:-upload}
ARCH=$(arch)
UUID=${UUID:-local}
OSTREE_COMMIT_DIR="/var/lib/osbuild-composer/artifacts"
OSTREE_COMMIT_FILE="${UUID}-${ARCH}-commit.tar"
OSTREE_COMMIT_PATH="${OSTREE_COMMIT_DIR}/${OSTREE_COMMIT_FILE}"
S3_BUCKET_NAME="fedora-testing-farm-image-import"
AWS_CLI="aws"
AWS_REGION="us-east-2"

echo "[+] Install dependencies"
if ! command -v aws ; then
    dnf install -y awscli
fi

echo "[+] Configure AWS settings"
$AWS_CLI configure set default.region "$AWS_REGION"
$AWS_CLI configure set default.output json

upload() {
    if [ ! -r "${OSTREE_COMMIT_PATH}" ]; then
        echo "Error: the file ${OSTREE_COMMIT_PATH} doesn't exist"
        exit 1
    fi
    echo "[+] Uploading OSTree Commit to 's3://${S3_BUCKET_NAME}/${OSTREE_COMMIT_FILE}"
    $AWS_CLI s3 cp "${OSTREE_COMMIT_PATH}" "s3://${S3_BUCKET_NAME}" --only-show-errors
}

download() {
    if [ ! -d "${OSTREE_COMMIT_DIR}" ]; then
        mkdir -pv ${OSTREE_COMMIT_DIR}
    fi
    echo "[+] Downloading OSTree Commit to '${OSTREE_COMMIT_PATH}'"
    $AWS_CLI s3 cp  "s3://${S3_BUCKET_NAME}/${OSTREE_COMMIT_FILE}" "${OSTREE_COMMIT_PATH}" --only-show-errors
}

if [[ "${ACTION}" == "upload" ]]; then
    upload
else
    download
fi
