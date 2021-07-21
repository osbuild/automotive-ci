#!/bin/bash

echo "Fixing *-release files"
cat > /etc/os-release <<EOF
NAME="CentOS Stream"
VERSION="8"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="8"
PLATFORM_ID="platform:el8"
PRETTY_NAME="CentOS Stream 8"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:centos:centos:8"
HOME_URL="https://centos.org/"
BUG_REPORT_URL="https://bugzilla.redhat.com/"
REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux 8"
REDHAT_SUPPORT_PRODUCT_VERSION="CentOS Stream"
EOF

cat > /etc/redhat-release <<EOF
CentOS Stream release 8
EOF

echo "Remove ramaining composes"
composes=$(composer-cli compose list | awk '{ print $1 }')
for compose in $composes; do
    composer-cli compose cancel "$compose"
    composer-cli compose delete "$compose"
done

echo "Remove the old sources"
composer-cli sources delete copr_neptune

echo "Remove ostree commits"
rm -f /var/lib/osbuild-composer/artifacts/*-commit.tar

echo "Stop and undefine the remaining VMs"
vms=$(virsh list --all --name)
for vm in $vms; do
    virsh destroy "${vm}"
    virsh undefine "${vm}" --nvram
done

echo "Remove all the VM images"
for image in $(ls /var/lib/libvirt/images/); do
    virsh vol-delete --pool images "${image}"
done

echo "Remove the virtual network"
if virsh net-info integration > /dev/null 2>&1; then
    virsh net-destroy integration
    virsh net-undefine integration
fi

echo "Clean httpd directory"
rm -fr /var/www/html/{compose.json,ks.cfg,repo}

