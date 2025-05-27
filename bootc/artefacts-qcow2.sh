#!/bin/sh

set -Eeuo pipefail

# Source variables and environment
source ./env.sh

function bootc_image_builder () {
  local type="$1"
  local rpmmd="$2"
  local store="$3"
  local output="$4"
  local config_file="$5"
  local image="$6"
  shift 6
  local -a args=("$@")
  echo "Running bootc-image-builder with type = '$type', image = '$image' and opts = '$@'..."
  podman run --rm --network "$PODMAN_NETWORK" --privileged --security-opt label=type:unconfined_t \
             -v "$config_file:/config.toml:ro" -v "$output:/output" -v "$rpmmd:/rpmmd" -v "$store:/store" \
             -v /var/lib/containers/storage:/var/lib/containers/storage \
             -v "$REGISTRY_AUTH_FILE:/auth.json:ro" -e "REGISTRY_AUTH_FILE=/auth.json" \
             "$BOOTC_IMAGE:$RHEL_VERSION" --type "$type" --config /config.toml "$image" "${args[@]}"
}

arch="$(arch)"
mkdir -p cache-$arch/{rpmmd,store,output}

# Shortcut: tag the container image as if it had been pulled from the registry (save a roundtrip with the registry)
podman tag localhost/$NAME-$arch $TARGET_IMAGE

# Build ISO with Kickstart
#bootc_image_builder iso "$PWD/image-$arch/rpmmd" "$PWD/image-$arch/store" "$PWD/image-$arch/output" "$PWD/config-iso.toml" "$TARGET_IMAGE" --local --log-level info
#cp "image-$arch/output/bootiso/install.iso" "install-$NAME-$arch.iso"

# Build qcow2
bootc_image_builder qcow2 "$PWD/cache-$arch/rpmmd" "$PWD/cache-$arch/store" "$PWD/cache-$arch/output" "$PWD/config-qcow2.toml" "$TARGET_IMAGE" --local
cp "cache-$arch/output/qcow2/disk.qcow2" "disk-$NAME-$arch.qcow2"

# Remove shortcut to prevent side effects
podman rmi $TARGET_IMAGE
