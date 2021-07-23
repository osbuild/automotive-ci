#!/bin/bash
set -euo pipefail

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
OS_VARIANT=${OS_VARIANT:-}
IMAGE_TYPE=${IMAGE_TYPE:-}
UUID=${UUID:-local}
IMAGE_KEY="auto-${ARCH}-${UUID}"
OSTREE_COMMIT_PATH="/var/lib/osbuild-composer/artifacts/${UUID}-${ARCH}-commit.tar"
# Set ostree ref. This need to be 'rhel/8/*/edge', because it's hardcoded at the code
OSTREE_REF="rhel/8/${ARCH}/edge"
BOOT_LOCATION="http://mirror.centos.org/centos/8-stream/BaseOS/${ARCH}/os/"
KS_FILE_TEMPLATE=${KS_FILE_TEMPLATE:-}
KS_FILE=${KS_FILE:-}
NET_CONFIG=${NET_CONFIG:-}

# Set up the system
echo "[+] Install dependencies"
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf config-manager --set-enabled epel
dnf install -y httpd qemu-kvm libvirt-daemon-kvm virt-install firewalld
echo "[+] Enable services"
for service in libvirtd firewalld httpd; do
    systemctl start "${service}"
done

echo "[+] Unpack the OSTree commit"
tar -xf "${OSTREE_COMMIT_PATH}" -C "${HTTPD_PATH}"
rm -f "${OSTREE_COMMIT_PATH}"

# Set a customized dnsmasq configuration for libvirt so we always get the
# same address on bootup.
if virsh net-info integration > /dev/null 2>&1; then
    # If the network is created but down, it will fail
    virsh net-destroy integration || true
    virsh net-undefine integration
fi

virsh net-define "$NET_CONFIG"
virsh net-start integration

# Ensure SELinux is happy with our new images.
echo "[+] Running restorecon on image directory"
restorecon -Rv /var/lib/libvirt/images/

# Create raw file for virt install.
echo "[+] Create raw file for virt install"
LIBVIRT_IMAGE_PATH=/var/lib/libvirt/images/${IMAGE_KEY}.raw
qemu-img create -f raw "${LIBVIRT_IMAGE_PATH}" 6G

# Generate a temporary SSH key
ssh-keygen -t ecdsa -f "$SSH_KEY" -q -N ""
SSH_PUBLIC_KEY="${SSH_KEY}.pub"
SSH_PUBLIC_KEY_CONTENT="$(< $SSH_PUBLIC_KEY)"

# Write kickstart file for ostree image installation.
echo "[+] Generate kickstart file"
export IMAGE_TYPE OSTREE_REF SSH_PUBLIC_KEY_CONTENT
envsubst < "$KS_FILE_TEMPLATE" > "$KS_FILE"

# Install ostree image via anaconda.
echo "[+] Install ostree image via anaconda"
virt-install  --name="${IMAGE_KEY}"\
              --disk path="${LIBVIRT_IMAGE_PATH}",format=raw \
              --ram 3072 \
              --vcpus 2 \
              --network network=integration,mac=34:49:22:B0:83:30 \
              --os-type linux \
              --os-variant "${OS_VARIANT}" \
              --location "${BOOT_LOCATION}" \
              --initrd-inject="${KS_FILE}" \
              --extra-args="ks=file:/ks.cfg console=ttyS0,115200" \
              --nographics \
              --wait=-1 \
              --noreboot

