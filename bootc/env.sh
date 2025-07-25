###
### General
###
PODMAN_NETWORK="edge-ai"
RHEL_VERSION="9.6"
RHEL_IMAGE="registry.redhat.io/rhel9/rhel-bootc"
BOOTC_IMAGE="registry.redhat.io/rhel10/bootc-image-builder"
BOOTC_VERSION="10.0"
NAME="bootc-edge-ai"
TARGET_IMAGE="quay.io/nmasse-redhat/$NAME:latest"

# All architectures to build for
declare -a ARCHITECTURES=("x86_64" "aarch64")
#declare -a ARCHITECTURES=("aarch64")
declare -A PODMAN_ARCH_OPTS=(["aarch64"]="--platform linux/arm64/v8" ["x86_64"]="--platform linux/amd64")

###
### Environment Variables
###
export REGISTRY_AUTH_FILE="$PWD/auth.json"
