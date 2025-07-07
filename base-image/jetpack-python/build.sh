#!/bin/bash

set -Eeuo pipefail

TARGET_IMAGE="quay.io/nmasse-redhat/jetpack-multiarch-python:r36.4.0"
SOURCE_IMAGE="quay.io/nmasse-redhat/jetpack-multiarch:r36.4.0"
SOURCE_REF=jetpack
TARGET_REF=jetpack-python

# Login to registries
export REGISTRY_AUTH_FILE="$PWD/auth.json"
if [ ! -f "$REGISTRY_AUTH_FILE" ]; then
  echo "Logging in quay.io registry"
  podman login quay.io
  echo "Done"
  read -p "Press enter to continue "
fi

podman rmi -i "$SOURCE_IMAGE"
podman pull --platform linux/amd64 "$SOURCE_IMAGE"
podman tag "$SOURCE_IMAGE" "localhost/$SOURCE_REF-x86_64"
podman rmi -i "$SOURCE_IMAGE"
podman pull --platform linux/arm64/v8 "$SOURCE_IMAGE"
podman tag "$SOURCE_IMAGE" "localhost/$SOURCE_REF-aarch64"
podman rmi -i "$SOURCE_IMAGE"

buildah build --platform linux/amd64 -t localhost/$TARGET_REF-x86_64 --from "localhost/$SOURCE_REF-x86_64" .
buildah build --platform linux/arm64/v8 -t localhost/$TARGET_REF-aarch64 --from "localhost/$SOURCE_REF-aarch64" .

if podman manifest exists localhost/$TARGET_REF; then
  podman manifest rm localhost/$TARGET_REF
fi
podman manifest create localhost/$TARGET_REF
podman manifest add localhost/$TARGET_REF localhost/$TARGET_REF-x86_64
podman manifest add localhost/$TARGET_REF localhost/$TARGET_REF-aarch64
echo "pushing to $TARGET_IMAGE..."
read -p "Press enter to continue "
podman manifest push --all --format v2s2 localhost/$TARGET_REF "docker://$TARGET_IMAGE"
