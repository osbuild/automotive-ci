#!/bin/bash
set -euo pipefail

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
UUID=${UUID:-local}
IMAGE_KEY="auto-${ARCH}-${UUID}"
TEMPDIR=${TEMPDIR:-}
HTTPD_PATH=${HTTPD_PATH:-}

echo "[+] Cleaning up: start"
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
# Stop httpd
systemctl disable httpd --now

echo "[+] Cleaning up: done"
