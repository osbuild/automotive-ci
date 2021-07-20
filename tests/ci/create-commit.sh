#!/bin/bash
set -euo pipefail

# Get OS data.
source /etc/os-release

ID=${ID:-}
VERSION_ID=${VERSION_ID:-}
ARCH=$(arch)
IMAGE_TYPE=${IMAGE_TYPE:-}
HTTPD_PATH=${HTTPD_PATH:-}
NEPTUNE_SOURCE_FILE_TEMPLATE=${NEPTUNE_SOURCE_FILE_TEMPLATE:-}
NEPTUNE_SOURCE_FILE=${NEPTUNE_SOURCE_FILE:-}
BLUEPRINT_FILE=${BLUEPRINT_FILE:-}

# Set up variables.
UUID=${UUID:-local}
IMAGE_KEY="auto-${ARCH}-${UUID}"

# Set up temporary files.
TEMPDIR=$(mktemp -d)
COMPOSE_START=${TEMPDIR}/compose-start-${IMAGE_KEY}.json
COMPOSE_INFO=${TEMPDIR}/compose-info-${IMAGE_KEY}.json

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
    echo "[+] Preparing blueprint"
    composer-cli blueprints push "$blueprint_file"
    composer-cli blueprints depsolve "$blueprint_name"

    # Start the compose.
    echo "[+] Starting compose"
    composer-cli --json compose start "$blueprint_name" "$IMAGE_TYPE" | tee "$COMPOSE_START"
    COMPOSE_ID=$(jq -r '.build_id' "$COMPOSE_START")

    # Wait for the compose to finish.
    echo "[+] Waiting for compose to finish: ${COMPOSE_ID}"
    while true; do
        composer-cli --json compose info "${COMPOSE_ID}" | tee "$COMPOSE_INFO" > /dev/null
        COMPOSE_STATUS=$(jq -r '.queue_status' "$COMPOSE_INFO")

        # Is the compose finished?
        if [[ $COMPOSE_STATUS != RUNNING ]] && [[ $COMPOSE_STATUS != WAITING ]]; then
            echo ; echo "[+] Finished compose"
            break
        fi
        echo -n "."

        # Wait 30 seconds and try again.
        sleep 30
    done

    # Capture the compose logs from osbuild.
    echo "[+] Getting compose log and metadata"
    get_compose_log "$COMPOSE_ID"
    get_compose_metadata "$COMPOSE_ID"

    # Did the compose finish with success?
    if [[ $COMPOSE_STATUS != FINISHED ]]; then
        echo "[-] Something went wrong with the compose. 😢"
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

# Set the correct arch for the the Neptune app source file.
export ARCH
envsubst < "$NEPTUNE_SOURCE_FILE_TEMPLATE" > "$NEPTUNE_SOURCE_FILE"

# Add COPR Neptune source
echo "[+] Add COPR Neptune source"
sudo composer-cli sources add "$NEPTUNE_SOURCE_FILE"
sudo composer-cli sources list
sudo composer-cli sources info copr_neptune

# Build installation image.
build_image "$BLUEPRINT_FILE" ostree

# Download the image and extract tar into web server root folder.
echo "[+] Downloading and extracting the image"
composer-cli compose image "${COMPOSE_ID}" > /dev/null
IMAGE_FILENAME="${COMPOSE_ID}-commit.tar"
tar -xf "${IMAGE_FILENAME}" -C "${HTTPD_PATH}"
rm -f "$IMAGE_FILENAME"

# Clean compose and blueprints.
echo "[+] Clean up osbuild-composer"
composer-cli compose delete "${COMPOSE_ID}" > /dev/null
composer-cli blueprints delete ostree > /dev/null

# Remove logs and temporary files
rm -rf "$TEMPDIR"
