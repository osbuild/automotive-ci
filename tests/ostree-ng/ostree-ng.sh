#!/usr/bin/env bash

# Install test dependencies
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm; sudo dnf config-manager --set-enabled epel
dnf install -y ansible jq qemu-img qemu-kvm libvirt-client libvirt-daemon-kvm virt-install git

# Clone the rhel-edge fork where we have a workaround to pull the container locally
git clone https://github.com/rasibley/rhel-edge.git; cd rhel-edge
git checkout skip_quay
chmod 600 key/ostree_key
./ostree-ng.sh

echo "Done"
