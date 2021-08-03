#!/bin/bash
set -eo pipefail

ARCH=$(arch)
UUID=${UUID:-local}
IMAGE_KEY="auto-${ARCH}-${UUID}"
DOWNLOAD_DIRECTORY="/var/lib/libvirt/images"
S3_BUCKET_NAME="fedora-testing-farm-image-import"
AWS_CLI="aws"
AWS_REGION="us-east-2"

echo "[+] Install dependencies"
dnf install -y awscli

echo "[+] Configure AWS settings"
$AWS_CLI configure set default.region "$AWS_REGION"
$AWS_CLI configure set default.output json

if [ ! -r "${SSH_KEY}" ]; then
    echo "Error: the file ${SSH_KEY} doesn't exist"
    exit 1
fi
echo "[+] Uploading ssh key for the image to 's3://${S3_BUCKET_NAME}/${IMAGE_KEY}.key"
$AWS_CLI s3 cp ${SSH_KEY} s3://${S3_BUCKET_NAME}/${IMAGE_KEY}.key --only-show-errors

if [ ! -r "${DOWNLOAD_DIRECTORY}/${IMAGE_KEY}.raw" ]; then
    echo "Error: the file ${DOWNLOAD_DIRECTORY}/${IMAGE_KEY}.raw doesn't exist"
    exit 1
fi
echo "[+] Uploading raw image to 's3://${S3_BUCKET_NAME}/${IMAGE_KEY}.raw"
$AWS_CLI s3 cp ${DOWNLOAD_DIRECTORY}/${IMAGE_KEY}.raw s3://${S3_BUCKET_NAME} --only-show-errors

echo "[+] Import snapshot to EC2"
IMPORT_SNAPSHOT_ID=$($AWS_CLI ec2 import-snapshot --disk-container Format=raw,UserBucket="{S3Bucket=${S3_BUCKET_NAME},S3Key=${IMAGE_KEY}.raw}" | jq -r .ImportTaskId)

echo "[+] Waiting for snapshot $IMPORT_SNAPSHOT_ID import"

until [ "$status" == "completed" ]; do
    status=$($AWS_CLI ec2 describe-import-snapshot-tasks --import-task-ids $IMPORT_SNAPSHOT_ID | jq -r .ImportSnapshotTasks[0].SnapshotTaskDetail.Status)
    echo -n "."
done
echo "snapshot status: $status"

$AWS_CLI ec2 describe-import-snapshot-tasks --import-task-ids $IMPORT_SNAPSHOT_ID
SNAPSHOT_ID=$($AWS_CLI ec2 describe-import-snapshot-tasks --import-task-ids $IMPORT_SNAPSHOT_ID | jq -r .ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId)

$AWS_CLI ec2 create-tags --resources $SNAPSHOT_ID --tags Key=ServiceComponent,Value=Automotive Key=ServiceOwner,Value=A-TEAM Key=ServicePhase,Value=Prod Key=FedoraGroup,Value=ci

echo "[+] Remove snapshot from s3"
$AWS_CLI s3 rm s3://${S3_BUCKET_NAME}/${IMAGE_KEY}.raw

echo "[+] Register AMI from snapshot"
IMAGE_ID=$($AWS_CLI ec2 register-image --name ${IMAGE_KEY}  --architecture arm64 --virtualization-type hvm --root-device-name "/dev/sda1" --block-device-mappings "[
    {
        \"DeviceName\": \"/dev/sda1\",
        \"Ebs\": {
            \"SnapshotId\": \"$SNAPSHOT_ID\"
        }
    }]" | jq -r .ImageId
)

$AWS_CLI ec2 create-tags --resources $IMAGE_ID --tags Key=ServiceComponent,Value=Artemis Key=ServiceName,Value=Artemis Key=AppCode,Value=ARR-001 Key=ServiceOwner,Value=TFT Key=ServicePhase,Value=Prod Key=GITHUB_RUN_ID,Value="${GITHUB_RUN_ID}"

# Wait for image registration
echo "[+] Waiting for image $IMAGE_ID registration"
until [ "$state" == "available" ]; do
    state=$($AWS_CLI ec2 describe-images --image-ids $IMAGE_ID | jq -r .Images[0].State)
    echo -n "."
done
echo "image state: $state"
$AWS_CLI ec2 describe-images --image-ids $IMAGE_ID
