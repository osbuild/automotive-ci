#!/bin/bash
set -euo pipefail

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
UUID=${UUID:-local}
IMAGE_KEY="auto-${ARCH}-${UUID}"
GUEST_ADDRESS=${GUEST_ADDRESS:-}
SSH_KEY=${SSH_KEY:-}

# SSH setup.
SSH_OPTIONS=(-q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i ${SSH_KEY} admin@${GUEST_ADDRESS})

ssh_run () {
    cmd="$*"
    ssh "${SSH_OPTIONS[@]}" "/bin/bash -c '${cmd}'"
}

# Wait for the ssh server up to be.
wait_for_ssh_up () {
    SSH_STATUS=$(ssh_run "echo -n READY")
    if [[ "$SSH_STATUS" == READY ]]; then
        echo 1
    else
        echo 0
    fi
}

# Helper function for the tests
assert () {
    local actual="$1"
    local expected="$2"

    if [[ "$actual" == "$expected" ]]; then
        echo "💚 Success"
    else
        echo "❌ Failed"
        ssh_run "free -h ; df -h ; ps aux | grep edge ; journalctl -p err -n 100"
        exit 1
    fi
}

assert_process_running () {
    process="$1"
    processes=$(ssh_run "ps -u edge a | grep -v grep | grep -c ${process}") || true

    assert "$processes" "1"
}

assert_package_installed () {
    package="$1"
    installed=$(ssh_run "rpm --quiet -q ${package} ; echo \$?")

    assert "$installed" "0"
}


# Tests definitions
test_is_centos () {
    echo "Checking if the OS running is CentOS"
    OS_ID=$(ssh_run "source /etc/os-release ; echo \$ID")

    assert "$OS_ID" "centos"
}

test_neptune_is_installed () {
    echo "Checking if the Neptune package is installed"

    assert_package_installed "neptune3-ui"
}

test_gnome_is_running () {
    echo "Checking if GNOME is running"

    assert_process_running "/usr/bin/gnome-shell"
}

test_neptune_is_running () {
    echo "Checking if Neptune is running"

    assert_process_running "neptune3-ui"
}


# Start VM.
echo "[+] Start VM"
virsh start "${IMAGE_KEY}"

# Check for ssh ready to go.
echo "[+] Checking for SSH is ready to go"
for LOOP_COUNTER in $(seq 0 30); do
    RESULTS="$(wait_for_ssh_up $GUEST_ADDRESS)"
    if [[ "$RESULTS" == 1 ]]; then
        break
    fi
    sleep 10
done


# Tests
echo "🛃 Tests 🛃"

test_is_centos

test_neptune_is_installed

# Wait a bit for the X and the app to start
sleep 30
test_gnome_is_running

# FIXME: Neptune app is starting but crashing. Jira issue: VROOM-418
# Uncomment this tests when the Neptune app stops crashing, to avoid
# false negatives to other PRs.
#test_neptune_is_running

