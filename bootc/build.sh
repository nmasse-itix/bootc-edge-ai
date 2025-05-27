#!/bin/sh

set -Eeuo pipefail

# Source variables and environment
source ./env.sh

# Login to registries, pull, etc.
./common.sh

# Build images
declare -A PODMAN_ARCH_OPTS=(["aarch64"]="--platform linux/arm64/v8" ["x86_64"]="--platform linux/amd64")
for arch in "${ARCHITECTURES[@]}"; do
  echo "Building $NAME image for $arch..."
  rm -rf etc
  tar -xf etc-$arch.tar
  mkdir -p cache-$arch/dnf cache-$arch/rpm-ostree
  podman build ${PODMAN_ARCH_OPTS[$arch]} --no-cache --from "$RHEL_IMAGE-$arch:$RHEL_VERSION" \
               -v $PWD/etc/pki/entitlement/:/etc/pki/entitlement:z -v $PWD/etc/rhsm:/etc/rhsm:z \
               -v $PWD/etc/pki/entitlement/:/run/secrets/etc-pki-entitlement:z -v $PWD/etc/rhsm:/run/secrets/rhsm:z \
               -v $PWD/etc/yum.repos.d:/etc/yum.repos.d:z -v $PWD/cache-$arch/dnf:/var/cache/dnf:z \
               -v $PWD/cache-$arch/rpm-ostree:/var/cache/rpm-ostree:z \
               --network $PODMAN_NETWORK -t localhost/$NAME-$arch .
  podman save --format oci-archive -o $NAME-$arch.tar localhost/$NAME-$arch
done

# Push Manifest
echo "Pushing to $TARGET_IMAGE..."
read -p "Press enter to continue "
if podman manifest exists localhost/$NAME; then
  podman manifest rm localhost/$NAME
fi
podman manifest create localhost/$NAME
for arch in "${ARCHITECTURES[@]}"; do
  podman manifest add localhost/$NAME localhost/$NAME-$arch
done
podman manifest push localhost/$NAME $TARGET_IMAGE
