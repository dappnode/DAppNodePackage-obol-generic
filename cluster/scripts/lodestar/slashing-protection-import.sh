#!/bin/bash

INFO="[ INFO | lodestar-slashing-protection-import ]"
ERROR="[ ERROR | lodestar-slashing-protection-import ]"

INTERCHANGE_FILE=${SLASHING_PROTECTION_DIR}/interchange.json
SYNCED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-synced

# Imports the interchange file into the slashing protection DB before the validator starts,
# when it is not already in it (e.g. it was restored from a backup). Importing merges, so
# records already in the DB are kept.
function import_slashing_protection() {
    local checksum

    if [ ! -f "${INTERCHANGE_FILE}" ]; then
        echo "${INFO} No slashing protection interchange file to import"
        return 0
    fi

    checksum=$(sha256sum "${INTERCHANGE_FILE}" | cut -d' ' -f1)

    if [ "${checksum}" = "$(cat "${SYNCED_FILE}" 2>/dev/null)" ]; then
        echo "${INFO} Slashing protection interchange file already in the DB"
        return 0
    fi

    echo "${INFO} Importing slashing protection data from ${INTERCHANGE_FILE}"

    if ! ${VALIDATOR_SERVICE_BIN} validator slashing-protection import \
        --network="${NETWORK}" \
        --dataDir="${VALIDATOR_DATA_DIR}" \
        --file="${INTERCHANGE_FILE}"; then
        echo "${ERROR} Slashing protection import failed, the validator will not start without it"
        sleep 60 # Avoid a tight restart loop
        return 1
    fi

    echo "${checksum}" >"${SYNCED_FILE}"
}

import_slashing_protection
