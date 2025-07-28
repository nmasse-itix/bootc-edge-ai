#!/bin/bash

# -------------------------------------------------------------------------------
# This script listens to an MQTT topic to receive image update notifications
# and triggers the system update process via bootc if the new digest is
# different from the one currently deployed.
#
# Dependencies:
# - bootc
# - jq
# - mosquitto_sub (from the mosquitto-clients package)
#
# Required environment variables:
# - MQTT_URL: The MQTT url.
# - MOSQUITTO_OPTS: The extra options to pass to mosquitto.
# 
# -------------------------------------------------------------------------------

MQTT_URL="mqtts://mosquitto-build-multiarch.apps.nmasse-q2-2025.sandbox1038.opentlc.com:443/bootc/updates"
MOSQUITTO_OPTS="--insecure --cafile service-ca.crt -k 15"

# Exit immediately if a command fails, if an unset variable is used,
# or if a command in a pipeline fails.
set -Eeuo pipefail

# --- Log a message to stderr ----
function _log () {
  echo "$@" >&2
}

_log "✅ Update script started."

# --- Function to run mosquitto ----
function get_mqtt_message () {
    _log "ℹ️ Mosquitto command: mosquitto_sub $mosquitto_opts $MOSQUITTO_OPTS -L "$MQTT_URL" -C 1"
    local return_code=0
    mosquitto_sub $mosquitto_opts $MOSQUITTO_OPTS -L "$MQTT_URL" -C 1 || return_code=$?
    _log "ℹ️ Mosquitto command returned with code: $return_code"
    if [[ $? -ne 27 ]] && [[ $? -ne 0 ]]; then # 27 is the exit code for a timeout, which we can ignore
        _log "❗️ Error: Mosquitto connection failed. Please check the MQTT URL and network connectivity."
        return $?
    fi
}

# 1. Get the current image and digest
_log "🔍 Checking the current image..."
CURRENT_IMAGE_REF=$(bootc status --format json | jq -r '.spec.image.image')

# Extracts the digest and the base image (e.g., registry/path/image)
# Handles the case where the image is tagged by digest (with '@')
if [[ "$CURRENT_IMAGE_REF" == *"@sha256:"* ]]; then
    CURRENT_IMAGE_BASE=$(echo "$CURRENT_IMAGE_REF" | cut -d'@' -f1)
    CURRENT_DIGEST=$(echo "$CURRENT_IMAGE_REF" | cut -d'@' -f2)
    _log "ℹ️ Current image: $CURRENT_IMAGE_BASE"
    _log "ℹ️ Current digest : $CURRENT_DIGEST"
elif [[ "$CURRENT_IMAGE_REF" == *":"* ]]; then
    # If the image is tagged by a tag (e.g., :latest), we cannot compare the digest.
    # The script will continue but will trigger an update on the first digest received.
    CURRENT_IMAGE_BASE=$(echo "$CURRENT_IMAGE_REF" | cut -d':' -f1)
    CURRENT_DIGEST=""
    _log "⚠️ The current image ($CURRENT_IMAGE_REF) is using a tag. Any new digest notification will trigger an update."
else
    CURRENT_IMAGE_BASE="$CURRENT_IMAGE_REF"
    CURRENT_DIGEST=""
    _log "⚠️ The current image ($CURRENT_IMAGE_REF) has neither digest nor tag. Any new digest notification will trigger an update."
fi

# --- Main Loop ---
mosquitto_opts="-W 10 --retained-only"
stale="1"
_log "♻️ Processing stale update triggers..."
while true; do
    # 2. Wait for an MQTT message containing the new digest
    _log "📡 Waiting for a message..."
    # The `-C 1` flag makes mosquitto_sub exit after receiving one message.
    NEW_DIGEST=$(get_mqtt_message)

    if [[ -z "$NEW_DIGEST" ]]; then
        _log "⚠️ No message received from the MQTT broker. Delaying for 10 seconds before retrying..."
        sleep 10 # Short pause before retrying
    else
        _log "📩 New digest received: $NEW_DIGEST"

        # 3. Compare the digests and act accordingly
        if [[ "$NEW_DIGEST" != "$CURRENT_DIGEST" ]]; then
            _log "✨ New digest detected! Starting the update process."

            # Build the new full image reference
            NEW_IMAGE_REF="${CURRENT_IMAGE_BASE}@${NEW_DIGEST}"
            _log "ℹ️ New target image: $NEW_IMAGE_REF"

            # Running update commands
            _log "🚀 Executing 'bootc switch'..."
            bootc switch "$NEW_IMAGE_REF"

            _log "🔄 Rebooting the system to apply the update..."
            reboot
            
            # The script stops here due to the reboot
            exit 0
        else
            _log "👍 The received digest is identical to the current one. No action required."
            _log "😴 Returning to listening mode..."
        fi
    fi

    # Up frow now, process only fresh messages
    if [[ "$stale" -eq "1" ]]; then
        _log "✨ Processing fresh update triggers only from now on."
        mosquitto_opts="-R"
        stale="0"
    fi
done
