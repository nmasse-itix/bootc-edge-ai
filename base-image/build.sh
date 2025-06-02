#!/bin/bash

set -Eeuo pipefail

ARM64_BASE_IMAGE="nvcr.io/nvidia/l4t-jetpack:r36.4.0"
AMD64_BASE_IMAGE="nvcr.io/nvidia/base/ubuntu:22.04_20240212"
TARGET_IMAGE="quay.io/nmasse-redhat/jetpack-multiarch:r36.4.0"

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
podman tag "$ARM64_BASE_IMAGE" localhost/base-image-aarch64

# Package a similar version for x86 without all the CUDA libraries
podman pull --platform linux/amd64 "$AMD64_BASE_IMAGE"
buildah build --platform linux/amd64 --from "$AMD64_BASE_IMAGE" -t localhost/base-image-x86_64 .

if podman manifest exists localhost/base-image; then
  podman manifest rm localhost/base-image
fi
podman manifest create localhost/base-image
podman manifest add localhost/base-image localhost/base-image-x86_64
podman manifest add localhost/base-image localhost/base-image-aarch64
podman manifest push localhost/base-image "$TARGET_IMAGE"
