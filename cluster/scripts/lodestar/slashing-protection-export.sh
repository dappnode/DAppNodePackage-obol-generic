#!/bin/bash

INFO="[ INFO | lodestar-slashing-protection-export ]"
ERROR="[ ERROR | lodestar-slashing-protection-export ]"

VALIDATOR_DB_DIR=${VALIDATOR_DATA_DIR}/validator-db
INTERCHANGE_FILE=${SLASHING_PROTECTION_DIR}/interchange.json
# sha256 of the interchange file whose data is in the validator DB (exported from or imported into it)
SYNCED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-synced
TMP_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-export.json
# Lodestar is stopped within its supervisord stopwaitsecs (30s)
LOCK_WAIT_ATTEMPTS=20

# Exports the Lodestar slashing protection DB as an EIP-3076 interchange file to
# SLASHING_PROTECTION_DIR, the path the package backup declares. The validator must be
# stopped: it holds the DB lock, and it must not sign after the export.
function export_slashing_protection() {
    local output checksum attempt exported=false

    mkdir -p "${SLASHING_PROTECTION_DIR}"

    if [ ! -d "${VALIDATOR_DB_DIR}" ]; then
        echo "${INFO} No slashing protection DB, the validator has not run in this cluster"
        return 0
    fi

    # A restored backup puts its own interchange file here: keep it until the validator imports it
    if [ -f "${INTERCHANGE_FILE}" ] && [ "$(sha256sum "${INTERCHANGE_FILE}" | cut -d' ' -f1)" != "$(cat "${SYNCED_FILE}" 2>/dev/null)" ]; then
        echo "${INFO} ${INTERCHANGE_FILE} is not imported yet, it is kept until the validator starts and imports it"
        return 0
    fi

    echo "${INFO} Exporting slashing protection DB to ${INTERCHANGE_FILE}"

    # The validator may still be stopping (e.g. `supervisorctl restart all` stops every program
    # at once): wait for it to release the DB lock
    for attempt in $(seq 1 "${LOCK_WAIT_ATTEMPTS}"); do
        rm -f "${TMP_FILE}"
        output=$(${VALIDATOR_SERVICE_BIN} validator slashing-protection export \
            --network="${NETWORK}" \
            --dataDir="${VALIDATOR_DATA_DIR}" \
            --file="${TMP_FILE}" 2>&1) && exported=true && break
        [[ "${output}" == *"already in use"* ]] || break
        echo "${INFO} The validator still holds the DB, waiting for it to stop (${attempt}/${LOCK_WAIT_ATTEMPTS})"
        sleep 2
    done

    if [ "${exported}" != true ]; then
        rm -f "${TMP_FILE}"
        echo "${ERROR} ################################################################"
        echo "${ERROR} Slashing protection export FAILED, ${INTERCHANGE_FILE} is NOT up to date"
        echo "${ERROR} and a backup taken now would not protect the validators: ${output}"
        echo "${ERROR} ################################################################"
        return 1
    fi

    checksum=$(sha256sum "${TMP_FILE}" | cut -d' ' -f1)
    mv -f "${TMP_FILE}" "${INTERCHANGE_FILE}"
    echo "${checksum}" >"${SYNCED_FILE}"
    echo "${INFO} Slashing protection exported, sha256 ${checksum}"
}

export_slashing_protection
