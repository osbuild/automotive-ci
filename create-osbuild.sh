#!/bin/bash
set -euo pipefail

# Get OS data.
source /etc/os-release

ID=${ID:-}
ARCH=$(arch)
OS_VARIANT=${OS_VARIANT:-}
IMAGE_TYPE=${IMAGE_TYPE:-}
UUID=${UUID:-local}
BOOT_LOCATION="http://mirror.centos.org/centos/8-stream/BaseOS/${ARCH}/os/"



dnf -y copr enable @osbuild/osbuild
SEARCH_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/@osbuild/osbuild/epel-8-\$basearch/'
REPLACE_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/@osbuild/osbuild/centos-stream-8-$basearch/'
sed -i -e "s|$SEARCH_PATTERN|$REPLACE_PATTERN|" \
	/etc/yum.repos.d/_copr\:copr.fedorainfracloud.org\:group_osbuild\:osbuild.repo
dnf -y install osbuild osbuild-tools


dnf -y copr enable pingou/qtappmanager-fedora
SEARCH_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/epel-8-$basearch/'
REPLACE_PATTERN='baseurl=https://download.copr.fedorainfracloud.org/results/pingou/qtappmanager-fedora/centos-stream-8-$basearch/' 
sed -i -e "s|$SEARCH_PATTERN|$REPLACE_PATTERN|" \
	/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pingou:qtappmanager-fedora.repo
# should there be a dnf install something here?


# pulling manifests from gitlab - need to accept its CA cert to download with curl, otherwise errors:
# or use  insecure mode, -k

##openssl s_client -showcerts -connect gitlab.cee.redhat.com:443 \
#	2>/dev/null \
#	| openssl x509 -outform PEM > gitlab_cacert.pem
 

#curl --cacert gitlab_cacert.pem \
curl -k  \
	https://gitlab.cee.redhat.com/autobase/dumpinggrounds/-/raw/master/osbuild-manifests/rhel8-qemu-${ARCH}.mpp.json \
	> cs8-qemu-${ARCH}.mpp.json 


curl -k \
	https://gitlab.cee.redhat.com/autobase/dumpinggrounds/-/raw/master/osbuild-manifests/rhel8-qemu-${ARCH}.mpp.json \
	> cs8-qemu-${ARCH}.mpp.json 

osbuild-mpp cs8-qemu.mpp.json cs8-qemu.mpp.json.built


