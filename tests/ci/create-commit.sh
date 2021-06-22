#!/bin/bash
set -euo pipefail

source /tmp/.env

ID=${ID:-}
ARCH=${ARCH:-}
IMAGE_TYPE=${IMAGE_TYPE:-}
HTTPD_PATH=${HTTPD_PATH:-}

# Set up variables.
TEST_UUID=$(uuidgen)
IMAGE_KEY="osbuild-composer-ostree-test-${TEST_UUID}"

# Set up temporary files.
TEMPDIR=$(mktemp -d)
BLUEPRINT_FILE=${TEMPDIR}/blueprint.toml
SOURCE_FILE=${TEMPDIR}/copr_neptune.toml
COMPOSE_START=${TEMPDIR}/compose-start-${IMAGE_KEY}.json
COMPOSE_INFO=${TEMPDIR}/compose-info-${IMAGE_KEY}.json

# Save some VARs for the next step
cat >> /tmp/.env <<EOF
IMAGE_KEY=${IMAGE_KEY}
TEMPDIR=${TEMPDIR}
EOF

# Get the compose log.
get_compose_log () {
    COMPOSE_ID=$1
    LOG_FILE=osbuild-${ID}-${VERSION_ID}-${COMPOSE_ID}.log

    # Download the logs.
    composer-cli compose log "$COMPOSE_ID" | tee "$LOG_FILE" > /dev/null
}

# Get the compose metadata.
get_compose_metadata () {
    COMPOSE_ID=$1
    METADATA_FILE=osbuild-${ID}-${VERSION_ID}-${COMPOSE_ID}.json

    # Download the metadata.
    composer-cli compose metadata "$COMPOSE_ID" > /dev/null

    # Find the tarball and extract it.
    TARBALL=$(basename "$(find . -maxdepth 1 -type f -name "*-metadata.tar")")
    tar -xf "$TARBALL" -C "${TEMPDIR}"
    rm -f "$TARBALL"

    # Move the JSON file into place.
    cat "${TEMPDIR}"/"${COMPOSE_ID}".json | jq -M '.' | tee "$METADATA_FILE" > /dev/null
}

# Build ostree image.
build_image() {
    blueprint_file=$1
    blueprint_name=$2

    # Prepare the blueprint for the compose.
    greenprint "📋 Preparing blueprint"
    composer-cli blueprints push "$blueprint_file"
    composer-cli blueprints depsolve "$blueprint_name"

    # Start the compose.
    greenprint "🚀 Starting compose"
    composer-cli --json compose start "$blueprint_name" "$IMAGE_TYPE" | tee "$COMPOSE_START"
    COMPOSE_ID=$(jq -r '.build_id' "$COMPOSE_START")

    # Wait for the compose to finish.
    greenprint "⏱ Waiting for compose to finish: ${COMPOSE_ID}"
    while true; do
        composer-cli --json compose info "${COMPOSE_ID}" | tee "$COMPOSE_INFO" > /dev/null
        COMPOSE_STATUS=$(jq -r '.queue_status' "$COMPOSE_INFO")

        # Is the compose finished?
        if [[ $COMPOSE_STATUS != RUNNING ]] && [[ $COMPOSE_STATUS != WAITING ]]; then
            echo ; greenprint "🚀 Finished compose"
            break
        fi
        echo -n "."

        # Wait 30 seconds and try again.
        sleep 30
    done

    # Capture the compose logs from osbuild.
    greenprint "💬 Getting compose log and metadata"
    get_compose_log "$COMPOSE_ID"
    get_compose_metadata "$COMPOSE_ID"

    # Did the compose finish with success?
    if [[ $COMPOSE_STATUS != FINISHED ]]; then
        echo "Something went wrong with the compose. 😢"
	echo "Logs:"
	tail -100 "$LOG_FILE"
        exit 1
    fi
}

##################################################
##
## ostree image/commit installation
##
##################################################

# Write a source for the Neptune app.
tee "$SOURCE_FILE" > /dev/null << EOF
id = "copr_neptune"
name = "copr_neptune"
type = "yum-baseurl"
url = "https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/epel-8-${ARCH}"
check_gpg = false
check_ssl = false
system = false
EOF

# Add COPR Neptune source
greenprint "📝 Add COPR Neptune source"
sudo composer-cli sources add "$SOURCE_FILE"
sudo composer-cli sources list
sudo composer-cli sources info copr_neptune

# Write a blueprint for ostree image.
tee "$BLUEPRINT_FILE" > /dev/null << EOF
name = "ostree"
description = "A base ostree image"
version = "0.0.1"
modules = []
groups = []

[[packages]]
name = "ModemManager"
version = "*"

[[packages]]
name = "NetworkManager-adsl"
version = "*"

[[packages]]
name = "NetworkManager-ppp"
version = "*"

[[packages]]
name = "NetworkManager-wwan"
version = "*"

[[packages]]
name = "at-spi2-atk"
version = "*"

[[packages]]
name = "at-spi2-core"
version = "*"

[[packages]]
name = "avahi"
version = "*"

[[packages]]
name = "chrome-gnome-shell"
version = "*"

[[packages]]
name = "dconf"
version = "*"

[[packages]]
name = "gdm"
version = "*"

[[packages]]
name = "glib-networking"
version = "*"

[[packages]]
name = "glibc-langpack-en"
version = "*"

[[packages]]
name = "gnome-backgrounds"
version = "*"

[[packages]]
name = "gnome-bluetooth"
version = "*"

[[packages]]
name = "gnome-classic-session"
version = "*"

[[packages]]
name = "gnome-control-center"
version = "*"

[[packages]]
name = "gnome-disk-utility"
version = "*"

[[packages]]
name = "gnome-initial-setup"
version = "*"

[[packages]]
name = "gnome-remote-desktop"
version = "*"

[[packages]]
name = "gnome-session-wayland-session"
version = "*"

[[packages]]
name = "gnome-session-xsession"
version = "*"

[[packages]]
name = "gnome-settings-daemon"
version = "*"

[[packages]]
name = "gnome-shell"
version = "*"

[[packages]]
name = "gnome-software"
version = "*"

[[packages]]
name = "gnome-system-monitor"
version = "*"

[[packages]]
name = "gnome-terminal"
version = "*"

[[packages]]
name = "gnome-terminal-nautilus"
version = "*"

[[packages]]
name = "gnome-user-docs"
version = "*"

[[packages]]
name = "gvfs-afc"
version = "*"

[[packages]]
name = "gvfs-afp"
version = "*"

[[packages]]
name = "gvfs-archive"
version = "*"

[[packages]]
name = "gvfs-fuse"
version = "*"

[[packages]]
name = "gvfs-goa"
version = "*"

[[packages]]
name = "gvfs-gphoto2"
version = "*"

[[packages]]
name = "gvfs-mtp"
version = "*"

[[packages]]
name = "gvfs-smb"
version = "*"

[[packages]]
name = "libcanberra-gtk3"
version = "*"

[[packages]]
name = "libproxy-webkitgtk4"
version = "*"

[[packages]]
name = "librsvg2"
version = "*"

[[packages]]
name = "libsane-hpaio"
version = "*"

[[packages]]
name = "mesa-dri-drivers"
version = "*"

[[packages]]
name = "mesa-libEGL"
version = "*"

[[packages]]
name = "nautilus"
version = "*"

[[packages]]
name = "orca"
version = "*"

[[packages]]
name = "polkit"
version = "*"

[[packages]]
name = "tracker"
version = "*"

[[packages]]
name = "tracker-miners"
version = "*"

[[packages]]
name = "xdg-desktop-portal"
version = "*"

[[packages]]
name = "xdg-desktop-portal-gtk"
version = "*"

[[packages]]
name = "xdg-user-dirs-gtk"
version = "*"

[[packages]]
name = "ostree-grub2"
version = "*"

[[packages]]
name = "efibootmgr"
version = "*"

[[packages]]
name = "xorg-x11-server-Xwayland"
version = "*"

[[packages]]
name = "xdg-desktop-portal"
version = "*"

[[packages]]
name = "xdg-desktop-portal-gtk"
version = "*"

[[packages]]
name = "qt5"
version = "5.15.*"

[[packages]]
name = "qt5-qtapplicationmanager"
version = "5.15.*"

[[packages]]
name = "neptune3-ui"
version = "*"

[customizations.services]
enabled = [ "ostree-remount" ]
EOF

# Build installation image.
build_image "$BLUEPRINT_FILE" ostree

# Download the image and extract tar into web server root folder.
greenprint "📥 Downloading and extracting the image"
composer-cli compose image "${COMPOSE_ID}" > /dev/null
IMAGE_FILENAME="${COMPOSE_ID}-commit.tar"
tar -xf "${IMAGE_FILENAME}" -C "${HTTPD_PATH}"
rm -f "$IMAGE_FILENAME"

# Clean compose and blueprints.
greenprint "Clean up osbuild-composer"
composer-cli compose delete "${COMPOSE_ID}" > /dev/null
composer-cli blueprints delete ostree > /dev/null
