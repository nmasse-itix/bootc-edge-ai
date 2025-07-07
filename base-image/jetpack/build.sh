#!/bin/bash

set -Eeuo pipefail

ARM64_BASE_IMAGE="nvcr.io/nvidia/l4t-jetpack:r36.4.0"
AMD64_BASE_IMAGE="nvcr.io/nvidia/base/ubuntu:22.04_20240212"
TARGET_IMAGE="quay.io/nmasse-redhat/jetpack-multiarch:r36.4.0"
NAME=jetpack

# Login to registries
export REGISTRY_AUTH_FILE="$PWD/auth.json"
if [ ! -f "$REGISTRY_AUTH_FILE" ]; then
  echo "Logging in nvcr.io registry"
  podman login nvcr.io
  echo "Logging in quay.io registry"
  podman login quay.io
  echo "Done"
  read -p "Press enter to continue "
fi

# Fetch the ARM64 image from Nvidia
podman pull --platform linux/arm64/v8 "$ARM64_BASE_IMAGE"
podman tag "$ARM64_BASE_IMAGE" localhost/$NAME-aarch64

# Package a similar version for x86 without all the CUDA libraries
podman pull --platform linux/amd64 "$AMD64_BASE_IMAGE"
buildah build --platform linux/amd64 --from "$AMD64_BASE_IMAGE" -t localhost/$NAME-x86_64 .

if podman manifest exists localhost/$NAME; then
  podman manifest rm localhost/$NAME
fi
podman manifest create localhost/$NAME
podman manifest add localhost/$NAME localhost/$NAME-x86_64
podman manifest add localhost/$NAME localhost/$NAME-aarch64
podman manifest push --all --format v2s2 localhost/$NAME "docker://$TARGET_IMAGE"
