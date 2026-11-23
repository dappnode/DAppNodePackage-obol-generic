#!/bin/bash

INFO="[ INFO | lodestar-slashing-protection-import ]"
WARN="[ WARN | lodestar-slashing-protection-import ]"
ERROR="[ ERROR | lodestar-slashing-protection-import ]"

SYNCED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-synced
# Left by slashing-protection-export.sh when the export does not succeed: the interchange files are stale
FAILED_FILE=${SLASHING_PROTECTION_DIR}/EXPORT-FAILED.txt

function _interchange_checksum() {
    cat "${SLASHING_PROTECTION_DIR}"/interchange*.json 2>/dev/null | sha256sum | cut -d' ' -f1
}

# Imports the interchange files into the slashing protection DB before the validator starts,
# when they are not already in it (e.g. they were restored from a backup). Importing merges, so
# records already in the DB are kept.
function import_slashing_protection() {
    local checksum file

    # Not an interchange file, it is never imported. It is there after a failed or killed export
    # on this node, or it came with a restored backup that was taken after one
    if [ -f "${FAILED_FILE}" ]; then
        echo "${WARN} ################################################################"
        echo "${WARN} The slashing protection interchange files in ${SLASHING_PROTECTION_DIR} are stale:"
        sed "s/^/${WARN}   /" "${FAILED_FILE}"
        echo "${WARN} ################################################################"
    fi

    if ! compgen -G "${SLASHING_PROTECTION_DIR}/interchange*.json" >/dev/null; then
        echo "${INFO} No slashing protection interchange file to import"
        return 0
    fi

    checksum=$(_interchange_checksum)

    if [ "${checksum}" = "$(cat "${SYNCED_FILE}" 2>/dev/null)" ]; then
        echo "${INFO} Slashing protection interchange files already in the DB"
        return 0
    fi

    for file in "${SLASHING_PROTECTION_DIR}"/interchange*.json; do
        echo "${INFO} Importing slashing protection data from ${file}"

        if ! ${VALIDATOR_SERVICE_BIN} validator slashing-protection import \
            --network="${NETWORK}" \
            --dataDir="${VALIDATOR_DATA_DIR}" \
            --file="${file}"; then
            echo "${ERROR} Slashing protection import failed, the validator will not start without it"
            sleep 60 # Avoid a tight restart loop
            return 1
        fi
    done

    echo "${checksum}" >"${SYNCED_FILE}"
}

import_slashing_protection
