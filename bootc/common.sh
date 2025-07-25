#!/bin/sh

set -Eeuo pipefail

if [[ "$UID" -ne 0 ]]; then
  echo "This command must be run as root!"
  exit 1
fi

# Source variables and environment
source ./env.sh

# Pre-requisites
if ! podman network exists $PODMAN_NETWORK; then
  podman network create $PODMAN_NETWORK --disable-dns
fi

# Login to registries
if [ ! -f "$REGISTRY_AUTH_FILE" ]; then
  echo "Logging in registry.redhat.io"
  podman login registry.redhat.io
  echo "Logging in quay.io registry"
  podman login quay.io
    echo "Done"
  read -p "Press enter to continue "
fi

# Pull
echo "Pulling images..."
if ! podman image exists $BOOTC_IMAGE:$BOOTC_VERSION; then
  podman pull $BOOTC_IMAGE:$BOOTC_VERSION
fi
for arch in "${ARCHITECTURES[@]}"; do
  if ! podman image exists $RHEL_IMAGE-$arch:$RHEL_VERSION; then
    podman rmi -i $RHEL_IMAGE:$RHEL_VERSION
    podman pull ${PODMAN_ARCH_OPTS[$arch]} $RHEL_IMAGE:$RHEL_VERSION
    podman tag $RHEL_IMAGE:$RHEL_VERSION $RHEL_IMAGE-$arch:$RHEL_VERSION
    podman rmi $RHEL_IMAGE:$RHEL_VERSION
  fi
done
