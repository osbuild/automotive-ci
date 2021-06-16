sudo chmod 644 key/ostree_key
virsh list --all | egrep -o 'osbuild[^ ]*' > domains
cat domains | xargs -n1 virsh destroy
cat domains | xargs -n1 virsh undefine --nvram
rm -rf /var/tmp/tmt
true
