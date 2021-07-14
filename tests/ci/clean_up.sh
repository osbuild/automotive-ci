#!/bin/bash
set -euo pipefail

# Restore the *-release files
cp -fv "${TMPCI_DIR}"/os-release /etc/
cp -fv "${TMPCI_DIR}"/redhat-release /etc/

source /tmp/.env

ID=${ID:-}
IMAGE_KEY=${IMAGE_KEY:-}
TEMPDIR=${TEMPDIR:-}
HTTPD_PATH=${HTTPD_PATH:-}

greenprint "🧼 Cleaning up: start"
# Remove stop and remove the VM
virsh destroy "${IMAGE_KEY}" || true
virsh undefine "${IMAGE_KEY}" --nvram || true
virsh vol-delete --pool images "${IMAGE_KEY}".raw
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

# Remove temporary CI files
rm -fvr "${TMPCI_DIR}"
rm -fv /tmp/.env

greenprint "🧼 Cleaning up: done"
