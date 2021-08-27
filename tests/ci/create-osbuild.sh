#!/bin/bash
set -euo pipefail

# following steps as noted on https://hackmd.io/ZbUOkeIXTjaP7XVpTSsrNw?view

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
UUID=${UUID:-local}
DISK_IMAGE=${DISK_IMAGE:-"image_output/image/disk.img"}
IMAGE_FILE=${IMAGE_FILE:-"/var/tmp/osbuild-${ARCH}-${UUID}.img"}

# install osbuild and osbuild-tools, which contains osbuild-mpp utility
dnf -y copr enable @osbuild/osbuild
SEARCH_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/@osbuild/osbuild/epel-8-\$basearch/'
REPLACE_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/@osbuild/osbuild/centos-stream-8-$basearch/'
sed -i -e "s|$SEARCH_PATTERN|$REPLACE_PATTERN|" \
	/etc/yum.repos.d/_copr\:copr.fedorainfracloud.org\:group_osbuild\:osbuild.repo
# force python36, to avoid this osbuild's bug: https://github.com/osbuild/osbuild/issues/757
dnf -y install python36 osbuild osbuild-tools

# enable neptune copr repo
dnf -y copr enable pingou/qtappmanager-fedora
SEARCH_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/epel-8-$basearch/'
REPLACE_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/centos-stream-8-$basearch/' 
sed -i -e "s|$SEARCH_PATTERN|$REPLACE_PATTERN|" \
	/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pingou:qtappmanager-fedora.repo



# in order to add xorg conf file, we need to inject it into manifest, base64 encoded
SHA=$(sha256sum files/xorg.conf | awk '{ print $1 }')
BASE64=$(base64 -w0 files/xorg.conf)
PREPROCESSOR_FILE=osbuild-manifests/cs8/cs8-rpi4-tianocore-neptune.mpp.json 
OSBUILT_FILE=cs8-${ARCH}.mpp.json.built

echo "Preprocessing $PREPROCESSOR_FILE"
osbuild-mpp $PREPROCESSOR_FILE - \
	|sed s/XORGSHA/$SHA/ \
	| sed s/XORGBASE64/$BASE64/ > osbuilder-$ARCH.json \
	> $OSBUILT_FILE

# build the image
sudo osbuild \
	--store osbuild_store \
	--output-directory image_output \
	--export image \
	$OSBUILT_FILE

echo "[+] Moving the generated image"
sudo mv $DISK_IMAGE $IMAGE_FILE

# Clean up
echo "[+] Cleaning up"
sudo rm -fr image_output osbuild_store

echo "The final image is here: ${IMAGE_FILE}"
echo
