#!/bin/bash

INFO="[ INFO | lodestar-slashing-protection-export ]"
ERROR="[ ERROR | lodestar-slashing-protection-export ]"

VALIDATOR_DB_DIR=${VALIDATOR_DATA_DIR}/validator-db
# sha256 of the interchange files whose data is in the validator DB (exported from or imported into it)
SYNCED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-synced
TMP_DIR=${VALIDATOR_DATA_DIR}/.slashing-protection-export
# Lodestar is stopped within its supervisord stopwaitsecs (30s)
LOCK_WAIT_ATTEMPTS=20
# Lodestar writes the whole interchange file as one string, which fails above ~500 MB (~2.9M
# attestations, a DB of ~85 MB). Bigger DBs are exported in files of a few validators each.
SPLIT_DB_SIZE_MB=50
SPLIT_VALIDATORS_PER_FILE=5

# Exports the Lodestar slashing protection DB as EIP-3076 interchange files to
# SLASHING_PROTECTION_DIR, the path the package backup declares: interchange.json, or
# interchange-N.json for a big DB. The validator must be stopped: it holds the DB lock, and it
# must not sign after the export.

function _interchange_checksum() {
    cat "${SLASHING_PROTECTION_DIR}"/interchange*.json 2>/dev/null | sha256sum | cut -d' ' -f1
}

# Exports to file $1, for the pubkeys $2 (comma separated) or all of them. Returns 2 if the
# validator did not release the DB
function _export() {
    local output attempt

    for attempt in $(seq 1 "${LOCK_WAIT_ATTEMPTS}"); do
        output=$(${VALIDATOR_SERVICE_BIN} validator slashing-protection export \
            --network="${NETWORK}" \
            --dataDir="${VALIDATOR_DATA_DIR}" \
            --file="${1}" \
            ${2:+--pubkeys="${2}"} 2>&1) && return 0
        # The validator may still be stopping (e.g. `supervisorctl restart all` stops every
        # program at once): wait for it to release the DB lock
        [[ "${output}" == *"already in use"* ]] || break
        echo "${INFO} The validator still holds the DB, waiting for it to stop (${attempt}/${LOCK_WAIT_ATTEMPTS})"
        sleep 2
    done

    echo "${ERROR} Lodestar slashing protection export failed:"
    echo "${output}" | tail -5
    [[ "${output}" == *"already in use"* ]] && return 2
    return 1
}

# Exports the validators of the keystores in files of SPLIT_VALIDATORS_PER_FILE validators
function _export_split() {
    local pubkeys n=0

    echo "${INFO} Exporting in files of ${SPLIT_VALIDATORS_PER_FILE} validators, for the validators with a keystore"
    rm -f "${TMP_DIR}"/*

    while read -r pubkeys; do
        n=$((n + 1))
        _export "${TMP_DIR}/interchange-${n}.json" "${pubkeys}" || return 1
    done < <(find "${VALIDATOR_DATA_DIR}/keystores" -mindepth 1 -maxdepth 1 -type d -name '0x*' -printf '%f\n' |
        sort | xargs -r -n "${SPLIT_VALIDATORS_PER_FILE}" echo | tr ' ' ',')

    [ "${n}" -gt 0 ]
}

function _fail() {
    rm -rf "${TMP_DIR}"
    echo "${ERROR} ################################################################"
    echo "${ERROR} Slashing protection export FAILED, ${SLASHING_PROTECTION_DIR} is NOT up to date"
    echo "${ERROR} and a backup taken now would not protect the validators"
    echo "${ERROR} ################################################################"
    return 1
}

function export_slashing_protection() {
    local checksum status

    mkdir -p "${SLASHING_PROTECTION_DIR}"

    if [ ! -d "${VALIDATOR_DB_DIR}" ]; then
        echo "${INFO} No slashing protection DB, the validator has not run in this cluster"
        return 0
    fi

    # A restored backup puts its own interchange files here: keep them until the validator imports them
    if compgen -G "${SLASHING_PROTECTION_DIR}/interchange*.json" >/dev/null && [ "$(_interchange_checksum)" != "$(cat "${SYNCED_FILE}" 2>/dev/null)" ]; then
        echo "${INFO} ${SLASHING_PROTECTION_DIR} is not imported yet, it is kept until the validator starts and imports it"
        return 0
    fi

    echo "${INFO} Exporting slashing protection DB to ${SLASHING_PROTECTION_DIR}"
    rm -rf "${TMP_DIR}"
    mkdir -p "${TMP_DIR}"

    if [ "$(du -sm "${VALIDATOR_DB_DIR}" | cut -f1)" -gt "${SPLIT_DB_SIZE_MB}" ]; then
        _export_split
        status=$?
    else
        _export "${TMP_DIR}/interchange.json"
        status=$?
        # Too big for one file (see SPLIT_DB_SIZE_MB), unless the validator still holds the DB
        if [ "${status}" -eq 1 ]; then
            _export_split
            status=$?
        fi
    fi

    if [ "${status}" -ne 0 ]; then
        _fail
        return 1
    fi

    # Replace the previous files. Interrupted here, the files do not match SYNCED_FILE and are
    # imported (again) on the next start, which is harmless
    rm -f "${SLASHING_PROTECTION_DIR}"/interchange*.json
    mv "${TMP_DIR}"/interchange*.json "${SLASHING_PROTECTION_DIR}/"
    rm -rf "${TMP_DIR}"
    checksum=$(_interchange_checksum)
    echo "${checksum}" >"${SYNCED_FILE}"
    echo "${INFO} Slashing protection exported: $(cd "${SLASHING_PROTECTION_DIR}" && echo interchange*.json)"
}

export_slashing_protection
