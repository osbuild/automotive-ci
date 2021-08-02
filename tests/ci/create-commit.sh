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

ID=${ID:-}
VERSION_ID=${VERSION_ID:-}
ARCH=$(arch)
IMAGE_TYPE=${IMAGE_TYPE:-}
HTTPD_PATH=${HTTPD_PATH:-}
NEPTUNE_SOURCE_FILE_TEMPLATE=${NEPTUNE_SOURCE_FILE_TEMPLATE:-}
NEPTUNE_SOURCE_FILE=${NEPTUNE_SOURCE_FILE:-}
BLUEPRINT_FILE=${BLUEPRINT_FILE:-}

UUID=${UUID:-local}
IMAGE_KEY="auto-${ARCH}-${UUID}"
OSTREE_COMMIT_PATH="/var/lib/osbuild-composer/artifacts/${UUID}-${ARCH}-commit.tar"

# Set up temporary files.
TEMPDIR=$(mktemp -d)
COMPOSE_START=${TEMPDIR}/compose-start-${IMAGE_KEY}.json
COMPOSE_INFO=${TEMPDIR}/compose-info-${IMAGE_KEY}.json

#############################
#          Functions        #
#############################

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
## Set up the system to run osbuild
##
##################################################

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

# Install dependencies
echo "[+] Install dependencies"
dnf install -y osbuild-composer composer-cli jq
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
    echo "[+] Clean osbuild cache"
    rm -fr /etc/osbuild-composer/repositories/*
    rm -rf /var/cache/osbuild-composer/rpmmd/*
else
    mkdir -p /etc/osbuild-composer/repositories
fi

# Set os-variant and boot location used by virt-install.
if [[ "${ID}-${VERSION_ID}" == "centos-8" ]]; then
    echo "[+] Fix osbuild to support CentOS Stream 8"
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
mv -v "${IMAGE_FILENAME}" "${OSTREE_COMMIT_PATH}"

# Clean compose and blueprints.
echo "[+] Clean up osbuild-composer"
composer-cli compose delete "${COMPOSE_ID}" > /dev/null
composer-cli blueprints delete ostree > /dev/null

# Remove logs and temporary files
rm -rf "$TEMPDIR"

# Reverse CentOS Stream workaround
echo "[+] Reverse CentOS Stream workaround"
cp -fv "${TMPCI_DIR}/os-release" /etc/
cp -fv "${TMPCI_DIR}/redhat-release" /etc/
rm -rf "${TMPCI_DIR}"
