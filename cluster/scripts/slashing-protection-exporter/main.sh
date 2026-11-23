#!/bin/bash

INFO="[ INFO | slashing-protection-exporter ]"

# Exports the slashing protection DB when the container stops, so a backup copied from the
# stopped container has it exactly. supervisord stops programs in reverse priority order,
# waiting for each one: this program has the lowest priority, so it is stopped after
# Lodestar, once the validator can no longer sign and has released the DB lock.

function on_stop() {
    kill "${SLEEP_PID}" 2>/dev/null
    /usr/local/bin/scripts/lodestar/slashing-protection-export.sh
    exit 0
}

trap on_stop TERM INT

mkdir -p "${SLASHING_PROTECTION_DIR}"
echo "${INFO} The slashing protection DB will be exported to ${SLASHING_PROTECTION_DIR} when the container stops"

sleep infinity &
SLEEP_PID=$!
wait "${SLEEP_PID}"
