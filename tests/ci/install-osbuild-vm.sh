
#!/bin/bash 

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
OS_VARIANT=${OS_VARIANT:-}
UUID=${UUID:-local}
IMAGE_FILE=${IMAGE_FILE:-"$HOME/image_output/osbuild-${ARCH}-${UUID}.img"}

virsh shutdown neptune
virsh undefine neptune --nvram

virt-install --name neptune \
	--ram 3072 \
	--vcpus 2 \
	--arch $ARCH \
	--os-variant rhel8-unknown \
	--os-type linux \
	--network=user \
	--boot hd \
	--noreboot \
	--disk path=$IMAGE_FILE

virsh --connect qemu:///system start neptune

#virsh --connect qemu:///system start --console neptune
#virsh shutdown neptune
#virsh undefine neptune --nvram

