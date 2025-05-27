#!/bin/sh

set -Eeuo pipefail

# Source variables and environment
source ./env.sh

# Constants
LOCAL_ARCH="$(arch)"
ARCH="${1:-$LOCAL_ARCH}"
TYPE="${2:-qcow2}"
DOMAIN_NAME="test-$NAME-$TYPE-$ARCH"

# Cleanup
if virsh list --name | grep -Eq "^$DOMAIN_NAME\$"; then
  virsh destroy "$DOMAIN_NAME"
fi
if virsh list --all --name | grep -Eq "^$DOMAIN_NAME\$"; then
  virsh undefine "$DOMAIN_NAME" --nvram
fi
rm -rf "/var/lib/libvirt/images/$DOMAIN_NAME"
mkdir -p "/var/lib/libvirt/images/$DOMAIN_NAME"

# Computing virt-install options
declare -a VIRT_INSTALL_OPTS=()
if [[ "$ARCH" != "$LOCAL_ARCH" ]]; then
  VIRT_INSTALL_OPTS+=("--virt-type" "qemu" "--arch" "$ARCH")
else
  VIRT_INSTALL_OPTS+=("--cpu" "host-passthrough")
fi
case "$TYPE" in
"qcow2")
  cp "disk-$NAME-$ARCH.qcow2" "/var/lib/libvirt/images/$DOMAIN_NAME/disk.qcow2"
  VIRT_INSTALL_OPTS+=("--disk" "path=/var/lib/libvirt/images/$DOMAIN_NAME/disk.qcow2,format=qcow2,bus=virtio,size=100"
                      "--import"
                      "--network" "network=default")
  ;;
"kickstart")
  cp "install-$NAME-$ARCH.iso" "/var/lib/libvirt/images/$DOMAIN_NAME/install.iso"
  VIRT_INSTALL_OPTS+=("--disk" "path=/var/lib/libvirt/images/$DOMAIN_NAME/disk.qcow2,format=qcow2,bus=virtio,size=100"
                      "--location" "/var/lib/libvirt/images/$DOMAIN_NAME/install.iso,kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img"
                      "--extra-args" "console=ttyS0 inst.ks=cdrom:/osbuild.ks"
                      "--network" "network=default")
  ;;
"kickstart-online")
  cp "install-$NAME-$ARCH-online.iso" "/var/lib/libvirt/images/$DOMAIN_NAME/install.iso"
  VIRT_INSTALL_OPTS+=("--disk" "path=/var/lib/libvirt/images/$DOMAIN_NAME/disk.qcow2,format=qcow2,bus=virtio,size=100"
                      "--location" "/var/lib/libvirt/images/$DOMAIN_NAME/install.iso,kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img"
                      "--extra-args" "console=ttyS0 inst.ks=cdrom:/osbuild.ks"
                      "--network" "network=default")
  ;;
"kickstart-offline")
  cp "install-$NAME-$ARCH-offline.iso" "/var/lib/libvirt/images/$DOMAIN_NAME/install.iso"
  VIRT_INSTALL_OPTS+=("--disk" "path=/var/lib/libvirt/images/$DOMAIN_NAME/disk.qcow2,format=qcow2,bus=virtio,size=100"
                      "--location" "/var/lib/libvirt/images/$DOMAIN_NAME/install.iso,kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img"
                      "--extra-args" "console=ttyS0 inst.ks=cdrom:/osbuild.ks"
                      "--network" "none")
  ;;
*)
  echo "Wrong artefact type $TYPE: expected either 'qcow2' or 'kickstart'."
  exit 1
  ;;
esac

# Boot VM
set -x
virt-install --name "$DOMAIN_NAME" --memory 4096 --vcpus 2 \
             --console pty,target_type=virtio --serial pty --graphics none \
             --os-variant rhel9-unknown --boot uefi \
             "${VIRT_INSTALL_OPTS[@]}"
