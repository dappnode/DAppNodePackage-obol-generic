#!/bin/bash

INFO="[ INFO | slashing-protection-exporter ]"
ERROR="[ ERROR | slashing-protection-exporter ]"

# Keeps an EIP-3076 interchange export of the Lodestar slashing protection DB in
# SLASHING_PROTECTION_DIR, the path the package backup declares. A raw copy of the
# live LevelDB taken by the backup can be inconsistent, this file is not.

EXPORT_INTERVAL=${SLASHING_PROTECTION_EXPORT_INTERVAL:-600}

VALIDATOR_DB_DIR=${VALIDATOR_DATA_DIR}/validator-db
INTERCHANGE_FILE=${SLASHING_PROTECTION_DIR}/interchange.json
# sha256 of the interchange file whose data is in the validator DB (exported from or imported into it)
SYNCED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-synced
# On the same volume as the DB so table files can be hard linked
SNAPSHOT_DIR=${VALIDATOR_DATA_DIR}/.slashing-protection-snapshot
TMP_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-export.json

# Lists the DB files. LevelDB only appends to its current log and manifest, any flush or
# compaction creates or deletes files, so the same list before and after a snapshot means
# that the snapshot is consistent.
function _list_db_files() {
    ls -1 "${VALIDATOR_DB_DIR}"
}

# Snapshots the DB without stopping the validator, which holds its lock. Table files are
# immutable and are hard linked, the rest is copied.
function _snapshot_db() {
    local before f

    for _ in 1 2 3; do
        rm -rf "${SNAPSHOT_DIR}"
        mkdir -p "${SNAPSHOT_DIR}/validator-db"
        before=$(_list_db_files)

        for f in "${VALIDATOR_DB_DIR}"/*; do
            case "${f}" in
            *.ldb | *.sst) ln "${f}" "${SNAPSHOT_DIR}/validator-db/" 2>/dev/null || cp -p "${f}" "${SNAPSHOT_DIR}/validator-db/" || continue 2 ;;
            *) cp -p "${f}" "${SNAPSHOT_DIR}/validator-db/" || continue 2 ;;
            esac
        done

        [ "${before}" = "$(_list_db_files)" ] && return 0
        sleep 1
    done

    return 1
}

function export_slashing_protection() {
    local output checksum

    if [ ! -d "${VALIDATOR_DB_DIR}" ]; then
        return 0 # The validator has not run yet in this cluster
    fi

    # A restored backup puts its own interchange file here: keep it until the validator imports it
    if [ -f "${INTERCHANGE_FILE}" ] && [ "$(sha256sum "${INTERCHANGE_FILE}" | cut -d' ' -f1)" != "$(cat "${SYNCED_FILE}" 2>/dev/null)" ]; then
        echo "${INFO} ${INTERCHANGE_FILE} is not imported yet, it is kept until the validator starts and imports it"
        return 0
    fi

    rm -f "${TMP_FILE}"

    if ! _snapshot_db; then
        echo "${ERROR} Could not take a consistent snapshot of ${VALIDATOR_DB_DIR}, keeping the previous export"
    # The snapshot also proves itself: LevelDB refuses to open it if a file it references is missing
    elif ! output=$(${VALIDATOR_SERVICE_BIN} validator slashing-protection export \
        --network="${NETWORK}" \
        --dataDir="${SNAPSHOT_DIR}" \
        --file="${TMP_FILE}" 2>&1); then
        echo "${ERROR} Slashing protection export failed, keeping the previous export: ${output}"
    else
        checksum=$(sha256sum "${TMP_FILE}" | cut -d' ' -f1)
        mv -f "${TMP_FILE}" "${INTERCHANGE_FILE}"
        echo "${checksum}" >"${SYNCED_FILE}"
    fi

    rm -rf "${SNAPSHOT_DIR}" "${TMP_FILE}"
}

mkdir -p "${SLASHING_PROTECTION_DIR}"

echo "${INFO} Exporting the slashing protection DB to ${INTERCHANGE_FILE} every ${EXPORT_INTERVAL}s"

while true; do
    export_slashing_protection
    sleep "${EXPORT_INTERVAL}"
done
