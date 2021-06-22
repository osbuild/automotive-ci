#!/bin/bash
set -euo pipefail

# Dumps details about the instance running the CI job.

CPUS=$(nproc)
MEM=$(free -m | grep -oP '\d+' | head -n 1)
DISK=$(df --output=size -h / | sed '1d;s/[^0-9]//g')
HOSTNAME=$(uname -n)
USER=$(whoami)
ARCH=$(uname -m)
KERNEL=$(uname -r)

# Get OS data.
source /etc/os-release

echo -e "\033[0;36m"
cat << EOF
------------------------------------------------------------------------------
CI MACHINE SPECS
------------------------------------------------------------------------------
     Hostname: ${HOSTNAME}
         User: ${USER}
         CPUs: ${CPUS}
          RAM: ${MEM} MB
         DISK: ${DISK} GB
         ARCH: ${ARCH}
       KERNEL: ${KERNEL}
           OS: ${ID}-${VERSION_ID}
------------------------------------------------------------------------------
EOF
echo -e "\033[0m"

echo "osbuild version"
rpm -qa | grep -i osbuild

# Create directory for CI files
TMPCI_DIR="/tmp/ci"
if [ -d "${TMPCI_DIR}" ]; then
    rm -fr "${TMPCI_DIR}"
fi
mkdir -v "${TMPCI_DIR}"

# Prepare osbuild-composer repository file
if [ -d /etc/osbuild-composer/repositories  ]; then
    # Clean previous runs repositories and cache
    rm -fr /etc/osbuild-composer/repositories/*
    rm -rf /var/cache/osbuild-composer/rpmmd/*
else
    mkdir -p /etc/osbuild-composer/repositories
fi

# Set ostree ref. This need to be 'rhel/8/*/edge', because it's hardoded at the code
OSTREE_REF="rhel/8/${ARCH}/edge"

# Set os-variant and boot location used by virt-install.
if [[ "${ID}-${VERSION_ID}" == "centos-8" ]]; then
    BOOT_LOCATION="http://mirror.centos.org/centos/8-stream/BaseOS/${ARCH}/os/"
    # CentOS Stream Workaround
    cp -fv /etc/os-release "${TMPCI_DIR}"
    cp -fv /etc/redhat-release "${TMPCI_DIR}"
    cp -fv tests/ci/files/rhel-8-4-0-os-release /etc/os-release
    cp -fv tests/ci/files/rhel-8-4-0-rh-release /etc/redhat-release
    cp -fv /usr/share/osbuild-composer/repositories/centos-stream-8.json /etc/osbuild-composer/repositories/
    ln -sfv /etc/osbuild-composer/repositories/centos-stream-8.json /etc/osbuild-composer/repositories/rhel-8.json
else
    echo "unsupported distro: ${ID}-${VERSION_ID}"
    exit 1
fi

# Start image builder service
if systemctl is-active osbuild-composer > /dev/null ; then
    systemctl restart osbuild-composer
else
    systemctl enable --now osbuild-composer.socket
fi

# Basic verification
composer-cli status show
composer-cli sources list
for SOURCE in $(composer-cli sources list); do
    composer-cli sources info "$SOURCE"
done

# Colorful output.
function greenprint {
    echo -e "\033[1;32m${1}\033[0m"
}

# Set a customized dnsmasq configuration for libvirt so we always get the
# same address on bootup.
tee /tmp/integration.xml > /dev/null << EOF
<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
  <name>integration</name>
  <uuid>1c8fe98c-b53a-4ca4-bbdb-deb0f26b3579</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='integration' zone='trusted' stp='on' delay='0'/>
  <mac address='52:54:00:36:46:ef'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.2' end='192.168.100.254'/>
      <host mac='34:49:22:B0:83:30' name='vm' ip='192.168.100.50'/>
    </dhcp>
  </ip>
</network>
EOF
if virsh net-info integration > /dev/null 2>&1; then
    # If the network is created but down, it will fail
    virsh net-destroy integration || true
    virsh net-undefine integration
fi

virsh net-define /tmp/integration.xml
virsh net-start integration

cat > /tmp/.env <<EOF
function greenprint {
    echo -e "\033[1;32m\${1}\033[0m"
}

ID=${ID}
ARCH=${ARCH}
VERSION_ID=${VERSION_ID}
TMPCI_DIR=${TMPCI_DIR}
OSTREE_REF=${OSTREE_REF}
BOOT_LOCATION=${BOOT_LOCATION}
EOF

exit 0
