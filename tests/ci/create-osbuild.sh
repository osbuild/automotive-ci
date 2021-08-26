#!/bin/bash
set -euo pipefail

# following steps as noted on https://hackmd.io/ZbUOkeIXTjaP7XVpTSsrNw?view

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
OS_VARIANT=${OS_VARIANT:-}
IMAGE_TYPE=${IMAGE_TYPE:-}
UUID=${UUID:-local}
DISK_IMAGE=${DISK_IMAGE:-"image_output/image/disk.img"}
IMAGE_FILE=${IMAGE_FILE:-"/var/lib/libvirt/images/osbuild-${ARCH}-${UUID}.img"}

# install osbuild and osbuild-tools, which contains osbuild-mpp utility
dnf -y copr enable @osbuild/osbuild
SEARCH_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/@osbuild/osbuild/epel-8-\$basearch/'
REPLACE_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/@osbuild/osbuild/centos-stream-8-$basearch/'
sed -i -e "s|$SEARCH_PATTERN|$REPLACE_PATTERN|" \
	/etc/yum.repos.d/_copr\:copr.fedorainfracloud.org\:group_osbuild\:osbuild.repo
dnf -y install osbuild osbuild-tools

# enable neptune copr repo
dnf -y copr enable pingou/qtappmanager-fedora
SEARCH_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/epel-8-$basearch/'
REPLACE_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/centos-stream-8-$basearch/' 
sed -i -e "s|$SEARCH_PATTERN|$REPLACE_PATTERN|" \
	/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pingou:qtappmanager-fedora.repo

# using templates copied from gitlab
# https://gitlab.cee.redhat.com/autobase/dumpinggrounds/-/tree/master/osbuild-manifests
# cs8-qemu-aarch64.mpp.json --> rhel-qemu-aarch.mpp.json
# cs8-build-aarch64.mpp.json --> rhel8-build-aarch64.mpp.json

# precompile the template
osbuild-mpp files/cs8-qemu.mpp.json cs8-${ARCH}.mpp.json.built

# build the image
sudo osbuild \
	--store osbuild_store \
	--output-directory image_output \
	--export image \
	cs8-${ARCH}.mpp.json.built

sudo mv $DISK_IMAGE $IMAGE_FILE

