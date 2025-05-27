#!/bin/sh

set -Eeuo pipefail

# Source variables and environment
source ./env.sh

# Kernel command line params per architecture
# Note: You can use multiple console= options; boot messages will be displayed on all consoles, but anaconda will put its display on the last console listed.
declare -A ARCH_KERNEL_CMDLINE=(["aarch64"]="console=ttyTCU0 console=tty0" ["x86_64"]="console=ttyS0 console=tty0")

###
### KICKSTART
###

##
## If you need to embed a file in the kickstart (pre/post script), encode it in Base32 as such:
##

# umask 0700
# mkdir -p \$XDG_RUNTIME_DIR/containers
# base32 -d > \$XDG_RUNTIME_DIR/containers/auth.json <<"EOB32"
# $(base32 -w 80 auth.json)
# EOB32

declare -a KICKSTART_ADDITIONAL_FILES_TAR_CMD_PRE=(  )
declare -a KICKSTART_ADDITIONAL_FILES_TAR_CMD_POST=( tar -zc -C post --owner=root --group=root . )
declare -A KICKSTART_SNIPPETS=()
KICKSTART_SNIPPETS+=( ["restart networkmanager"]="
systemctl restart --no-block NetworkManager.service
" )
KICKSTART_SNIPPETS+=( ["bootc switch"]="
bootc switch --mutate-in-place --transport registry $TARGET_IMAGE
" )
KICKSTART_SNIPPETS+=( ["/etc/ostree/auth.json"]="
base32 -d > /etc/ostree/auth.json <<\"EOB32\"
$(base32 -w 80 auth.json)
EOB32
chmod 600 /etc/ostree/auth.json
" )
KICKSTART_SNIPPETS+=( ["/etc/containers/registries.conf.d/bootc-registry.conf"]="
cat > /etc/containers/registries.conf.d/bootc-registry.conf <<\"EOF\"
[[registry]]
location=\"${TARGET_IMAGE%%/*}\"
insecure=true
EOF
" )

# Inject NetworkManager connections to kickstart
KICKSTART_SNIPPETS+=( ["/etc/NetworkManager/system-connections"]="" )
if [ -d root/etc/NetworkManager/system-connections ]; then
  for file in root/etc/NetworkManager/system-connections/*.nmconnection; do
    filename="$(basename "$file")"
    KICKSTART_SNIPPETS["/etc/NetworkManager/system-connections"]+="
base32 -d > \"/etc/NetworkManager/system-connections/$filename\" <<\"EOB32\"
$(base32 -w 80 "$file")
EOB32
"
  done
fi

# Inject arbitrary files in kickstart
if [ -d pre ]; then
  KICKSTART_SNIPPETS+=( ["additional files pre"]="
base32 -d <<\"EOB32\" | tar -zx -C / --warning=none
$(cd pre && tar -zc --owner=root --group=root * | base32 -w 80)
EOB32
" )
else
  KICKSTART_SNIPPETS+=( ["additional files pre"]="" )
fi
if [ -d post ]; then
  KICKSTART_SNIPPETS+=( ["additional files post"]="
base32 -d <<\"EOB32\" | tar -zx -C / --warning=none
$(cd post && tar -zc --owner=root --group=root * | base32 -w 80)
EOB32
" )
else
  KICKSTART_SNIPPETS+=( ["additional files post"]="" )
fi

KICKSTART_PREPOST_ONLINE="
##
## Pre/post-install scripts
##

%pre --interpreter=/bin/bash --logfile=/tmp/anaconda-pre.log --erroronfail
set -Eeuo pipefail
${KICKSTART_SNIPPETS["/etc/ostree/auth.json"]}
${KICKSTART_SNIPPETS["/etc/containers/registries.conf.d/bootc-registry.conf"]}
${KICKSTART_SNIPPETS["/etc/NetworkManager/system-connections"]}
${KICKSTART_SNIPPETS["additional files pre"]}
${KICKSTART_SNIPPETS["restart networkmanager"]}
%end

%post --interpreter=/bin/bash --logfile=/var/log/anaconda-post.log --erroronfail
set -Eeuo pipefail
${KICKSTART_SNIPPETS["/etc/ostree/auth.json"]}
${KICKSTART_SNIPPETS["/etc/containers/registries.conf.d/bootc-registry.conf"]}
${KICKSTART_SNIPPETS["/etc/NetworkManager/system-connections"]}
${KICKSTART_SNIPPETS["additional files post"]}

%end
"
KICKSTART_PREPOST_OFFLINE="
##
## Pre/post-install scripts
##

%pre --interpreter=/bin/bash --logfile=/tmp/anaconda-pre.log --erroronfail
${KICKSTART_SNIPPETS["additional files pre"]}
${KICKSTART_SNIPPETS["restart networkmanager"]}
%end

%post --interpreter=/bin/bash --logfile=/var/log/anaconda-post.log --erroronfail
set -Eeuo pipefail
${KICKSTART_SNIPPETS["/etc/ostree/auth.json"]}
${KICKSTART_SNIPPETS["/etc/containers/registries.conf.d/bootc-registry.conf"]}
${KICKSTART_SNIPPETS["bootc switch"]}
${KICKSTART_SNIPPETS["additional files post"]}
%end
"
declare -A KICKSTART_PREPOST=(["online"]="$KICKSTART_PREPOST_ONLINE" ["offline"]="$KICKSTART_PREPOST_OFFLINE")

# Types of ISO with kickstart to build
declare -a KICKSTART_TYPES=("online" "offline")

ARCH="$(arch)"
for type in "${KICKSTART_TYPES[@]}"; do
  KICKSTART_FILE="template-$type.ks"
  echo "Templating Kickstart $KICKSTART_FILE..."
  (
    export ARCH
    export TARGET_IMAGE
    export KERNEL_CMDLINE="${ARCH_KERNEL_CMDLINE[$ARCH]}"
    envsubst < "$KICKSTART_FILE" > osbuild.ks
    echo "${KICKSTART_PREPOST[$type]}" >> osbuild.ks
  )

  echo "Validating Kickstart..."
  ksvalidator osbuild.ks

  if [[ "$type" == "offline" ]]; then
    echo "Exporting container image..."
    # Shortcut: tag the container image as if it had been pulled from the registry (save a roundtrip with the registry)
    podman tag localhost/$NAME-$ARCH $TARGET_IMAGE
    # Export the container image as oci-dir to embed it later in the 
    mkdir -p cache-$ARCH
    rm -rf cache-$ARCH/container
    podman save --format oci-dir -o cache-$ARCH/container $TARGET_IMAGE
    # Remove shortcut to prevent side effects
    podman rmi $TARGET_IMAGE
  fi

  echo "Injecting artefacts into ISO $type..."
  rm -f "install-$NAME-$ARCH-$type.iso"
  if [[ "$type" == "offline" ]]; then
    mkkiso_extra_args="-a cache-$ARCH/container"
  else
    mkkiso_extra_args=""
  fi
  mkksiso -R 'set timeout=60' 'set timeout=5' -R 'set default="1"' 'set default="0"' -c "${ARCH_KERNEL_CMDLINE[$ARCH]}" $mkkiso_extra_args --ks "osbuild.ks" "rhel-$RHEL_VERSION-$ARCH-boot.iso" "install-$NAME-$ARCH-$type.iso"
done
