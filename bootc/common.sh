#!/bin/sh

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
if ! podman image exists $BOOTC_IMAGE:$RHEL_VERSION; then
  podman pull $BOOTC_IMAGE:$RHEL_VERSION
fi
if ! podman image exists $RHEL_IMAGE-x86_64:$RHEL_VERSION; then
  podman rmi -i $RHEL_IMAGE:$RHEL_VERSION
  podman pull --platform linux/amd64 $RHEL_IMAGE:$RHEL_VERSION
  podman tag $RHEL_IMAGE:$RHEL_VERSION $RHEL_IMAGE-x86_64:$RHEL_VERSION
  podman rmi $RHEL_IMAGE:$RHEL_VERSION
fi
if ! podman image exists $RHEL_IMAGE-aarch64:$RHEL_VERSION; then
  podman rmi -i $RHEL_IMAGE:$RHEL_VERSION
  podman pull --platform linux/arm64/v8 $RHEL_IMAGE:$RHEL_VERSION
  podman tag $RHEL_IMAGE:$RHEL_VERSION $RHEL_IMAGE-aarch64:$RHEL_VERSION
  podman rmi $RHEL_IMAGE:$RHEL_VERSION
fi
