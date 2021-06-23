#!/bin/bash
set -euo pipefail

source /tmp/.env

IMAGE_KEY=${IMAGE_KEY:-}
LIBVIRT_IMAGE_PATH=${LIBVIRT_IMAGE_PATH:-}
GUEST_ADDRESS=${GUEST_ADDRESS:-}
SSH_KEY=${SSH_KEY:-}

# SSH setup.
SSH_OPTIONS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)

# Wait for the ssh server up to be.
wait_for_ssh_up () {
    SSH_STATUS=$(ssh "${SSH_OPTIONS[@]}" -i "${SSH_KEY}" admin@"${1}" '/bin/bash -c "echo -n READY"')
    if [[ $SSH_STATUS == READY ]]; then
        echo 1
    else
        echo 0
    fi
}

# Test result checking
check_result () {
    greenprint "Checking for test result"
    if [[ $RESULTS == 1 ]]; then
	greenprint "Cheking OS version"
	ssh "${SSH_OPTIONS[@]}" -i "${SSH_KEY}" admin@"${GUEST_ADDRESS}" '/bin/bash -c "cat /etc/redhat-release"'
        greenprint "💚 Success"
    else
        greenprint "❌ Failed"
        clean_up
        exit 1
    fi
}

# Start VM.
greenprint "Start VM"
virsh start "${IMAGE_KEY}"

# Check for ssh ready to go.
greenprint "🛃 Checking for SSH is ready to go"
for LOOP_COUNTER in $(seq 0 30); do
    RESULTS="$(wait_for_ssh_up $GUEST_ADDRESS)"
    if [[ $RESULTS == 1 ]]; then
        echo "SSH is ready now! 🥳"
        break
    fi
    sleep 10
done

# Check image installation result
check_result

greenprint "Here is the resulted VM: $LIBVIRT_IMAGE_PATH"

