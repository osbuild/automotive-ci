#!/bin/bash
set -euo pipefail

source /tmp/.env

ID=${ID:-}
IMAGE_KEY=${IMAGE_KEY:-}
TEMPDIR=${TEMPDIR:-}
HTTPD_PATH=${HTTPD_PATH:-}

greenprint "🧼 Cleaning up: start"
# Remove stop and remove the VM
virsh destroy "${IMAGE_KEY}" || true
virsh undefine "${IMAGE_KEY}" --nvram
#TODO: Remove the resulted VM until we find a way to save it at S3
virsh vol-delete --pool images "${IMAGE_KEY}".qcow2
# Remove "remote" repo.
rm -rf "${HTTPD_PATH}"/{repo,compose.json}
# Remove virt network
if virsh net-info integration > /dev/null 2>&1; then
    # If the network is created but down, it will fail
    virsh net-destroy integration || true
    virsh net-undefine integration
fi
# Remomve tmp dir.
rm -rf "$TEMPDIR"
# Stop httpd
systemctl disable httpd --now
# Restore the *-release files
cp -fv "${TMPCI_DIR}"/os-release /etc/
cp -fv "${TMPCI_DIR}"/redhat-release /etc/

# Remove temporary CI files
rm -fvr "${TMPCI_DIR}"
rm -fv /tmp/.env

greenprint "🧼 Cleaning up: done"
