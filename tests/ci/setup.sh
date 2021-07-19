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
TMPCI_DIR=${TMPCI_DIR:-}
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
    #TODO: Temporary fix for a mirror issue
    # Use the main mirror, because the selected one gives errors when fetching the package lvm-compat-libs
    cp -fv tests/ci/files/centos-stream-8.json /etc/osbuild-composer/repositories/
    #cp -fv /usr/share/osbuild-composer/repositories/centos-stream-8.json /etc/osbuild-composer/repositories/
    ln -sfv /etc/osbuild-composer/repositories/centos-stream-8.json /etc/osbuild-composer/repositories/rhel-8.json
else
    echo "unsupported distro: ${ID}-${VERSION_ID}"
    exit 1
fi

# Colorful output.
function greenprint {
    echo -e "\033[1;32m${1}\033[0m"
}

exit 0
