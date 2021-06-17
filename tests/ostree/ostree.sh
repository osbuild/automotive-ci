#!/usr/bin/env bash

# cleanup before the test
./tests/ostree/cleanup.sh

# Install test dependencies
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf config-manager --set-enabled epel
dnf install -y ansible jq qemu-img qemu-kvm libvirt-client libvirt-daemon-kvm virt-install git
# TODO: workarounds
# git clone https://github.com/virt-s1/rhel-edge.git; cd rhel-edge
git clone -b c8s-support https://github.com/thrix/rhel-edge.git; cd rhel-edge
chmod 600 key/ostree_key
./ostree.sh

echo "Done"
