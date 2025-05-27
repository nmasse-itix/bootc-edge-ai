###
### General
###
PODMAN_NETWORK="edge-ai"
RHEL_VERSION="9.4"
RHEL_IMAGE="registry.redhat.io/rhel9/rhel-bootc"
BOOTC_IMAGE="registry.redhat.io/rhel9/bootc-image-builder"
NAME="bootc-edge-ai"
TARGET_IMAGE="quay.io/nmasse-redhat/$NAME:latest"

# All architectures to build for
declare -a ARCHITECTURES=("x86_64" "aarch64")

###
### Environment Variables
###
export REGISTRY_AUTH_FILE="$PWD/auth.json"
