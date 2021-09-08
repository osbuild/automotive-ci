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
PREPROCESSOR_FILE=tests/ci/osbuild-manifests/cs8/cs8-rpi4-tianocore-neptune.mpp.json
OSBUILT_FILE=tests/ci/cs8-${ARCH}.mpp.json.built

# TODO remove dnf clean when CI is running - this needed during development on re-used build machine
#dnf clean all

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


echo "Calculating sha and base64 encoding files"
echo ""

# in order to add xorg conf and other files, we need to inject it into manifest, base64 encoded
# TODO rather than overwrite /etx/X11/xorg.conf, should we add to /etc/X11/xorg.conf.d/ or /usr/share/X11/xorg.conf.d/ 
# add /etc/X11/xorg.conf
FILENAME=tests/ci/files/xorg.conf
echo "Calculating sha and base64 for $FILENAME"
XORGSHA=$(sha256sum $FILENAME | awk '{ print $1 }')
XORGBASE64=$(base64 -w0 $FILENAME)

# add /etc/gdm/custom.conf
FILENAME=tests/ci/files/gdm-custom.conf
echo "Calculating sha and base64 for $FILENAME"
GDMCONFSHA=$(sha256sum $FILENAME | awk '{ print $1 }')
GDMCONFBASE64=$(base64 -w0 $FILENAME)

# add /home/edge/.config/autostart/neptune3-ui.desktop
FILENAME=tests/ci/files/neptune3-ui.desktop
echo "Calculating sha and base64 for $FILENAME"
NEPTUNE_SHA=$(sha256sum $FILENAME | awk '{ print $1 }')
NEPTUNE_BASE64=$(base64 -w0 $FILENAME)

# add /home/edge/.config/autostart/gnome-initial-setup-done
FILENAME=tests/ci/files/gnome-initial-setup-done
echo "Calculating sha and base64 for $FILENAME"
echo 'yes' > $FILENAME
GNOME_INITIAL_SETUP_SHA=$(sha256sum $FILENAME | awk '{ print $1 }')
GNOME_INITIAL_SETUP_BASE64=$(base64 -w0 $FILENAME)

# Generate a temporary SSH key
# echo used here to force over-writing SSH_KEY file if it exists
echo -e 'y\n' | ssh-keygen -t ecdsa -f "$SSH_KEY" -q -N ""
SSH_PUBLIC_KEY="${SSH_KEY}.pub"
SSH_PUBLIC_KEY_CONTENT="$(< $SSH_PUBLIC_KEY)"

echo "Preprocessing $PREPROCESSOR_FILE"
# note - using ! as field separator as SSH_PUBLIC_KEY is a file path
osbuild-mpp $PREPROCESSOR_FILE - \
	| sed "s#XORGSHA#$XORGSHA#" \
	| sed "s#XORGBASE64#$XORGBASE64#" \
	| sed "s#GDMCONFSHA#$GDMCONFSHA#" \
	| sed "s#GDMCONFBASE64#$GDMCONFBASE64#" \
	| sed "s#NEPTUNE_SHA#$NEPTUNE_SHA#" \
	| sed "s#NEPTUNE_BASE64#$NEPTUNE_BASE64#" \
	| sed "s#GNOME_INITIAL_SETUP_SHA#$GNOME_INITIAL_SETUP_SHA#" \
	| sed "s#GNOME_INITIAL_SETUP_BASE64#$GNOME_INITIAL_SETUP_BASE64#" \
	| sed "s#TEMPSSHKEY#$SSH_PUBLIC_KEY_CONTENT#" \
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
