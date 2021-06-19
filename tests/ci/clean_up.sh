#!/bin/bash
set -euo pipefail

source /tmp/.env

ID=${ID:-}
IMAGE_KEY=${IMAGE_KEY:-}
TEMPDIR=${TEMPDIR:-}
HTTPD_PATH=${HTTPD_PATH:-}

greenprint "🧼 Cleaning up"
virsh destroy "${IMAGE_KEY}"
virsh undefine "${IMAGE_KEY}" --nvram
# Remove "remote" repo.
rm -rf "${HTTPD_PATH}"/{repo,compose.json}
# Remomve tmp dir.
rm -rf "$TEMPDIR"
# Stop httpd
systemctl disable httpd --now
# Restore the *-release files
if [[ "$ID" == "centos" ]]; then
    cp -fv files/os-release /etc/
    cp -vf files/redhat-release /etc/
fi
