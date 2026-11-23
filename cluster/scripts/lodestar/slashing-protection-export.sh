#!/bin/bash

INFO="[ INFO | lodestar-slashing-protection-export ]"
ERROR="[ ERROR | lodestar-slashing-protection-export ]"

VALIDATOR_DB_DIR=${VALIDATOR_DATA_DIR}/validator-db
# sha256 of the interchange files whose data is in the validator DB (exported from or imported into it)
SYNCED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-synced
# Fingerprint of the validator DB files right after the last successful export, see _db_fingerprint
EXPORTED_FILE=${VALIDATOR_DATA_DIR}/.slashing-protection-exported
TMP_DIR=${VALIDATOR_DATA_DIR}/.slashing-protection-export
# Marks the interchange files as stale. It is in the backed up dir, so a backup taken after a
# failed export says so. Written when an export starts, removed when it succeeds
FAILED_FILE=${SLASHING_PROTECTION_DIR}/EXPORT-FAILED.txt
# Time budget of the export, in seconds. It must stay below the stopwaitsecs of
# slashing-protection-exporter in supervisord.conf: after that supervisord kills the export with
# SIGKILL, which can not log anything nor clean up
EXPORT_TIMEOUT_SECS=${SLASHING_PROTECTION_EXPORT_TIMEOUT_SECS:-480}
# Lodestar is stopped within its supervisord stopwaitsecs (30s)
LOCK_WAIT_ATTEMPTS=20
# Lodestar writes the whole interchange file as one string, which fails above ~500 MB (~2.9M
# attestations, a DB of ~85 MB). Bigger DBs are exported in files of several validators each.
SPLIT_DB_SIZE_MB=50
# Size aimed at for each of those files, half of what Lodestar can write, see _validators_per_file
SPLIT_FILE_SIZE_MB=250
# Validators per file when there are no previous files to go by, and after a file was too big
SPLIT_VALIDATORS_PER_FILE=5

# Exports the Lodestar slashing protection DB as EIP-3076 interchange files to
# SLASHING_PROTECTION_DIR, the path the package backup declares: interchange.json, or
# interchange-N.json for a big DB. The validator must be stopped: it holds the DB lock, and it
# must not sign after the export.

function _interchange_checksum() {
    cat "${SLASHING_PROTECTION_DIR}"/interchange*.json 2>/dev/null | sha256sum | cut -d' ' -f1
}

# Names, sizes and modification times of the validator DB files. Every process that opens the DB
# changes them, even without writing a record (LevelDB starts a new LOG, MANIFEST and write-ahead
# log each time it is opened). So an unchanged fingerprint means that neither the validator nor
# the Lodestar CLI has opened the DB
function _db_fingerprint() {
    (
        set -o pipefail
        find "${VALIDATOR_DB_DIR}" -type f -printf '%P %s %T@\n' | sort | sha256sum | cut -d' ' -f1
    )
}

# True only if the DB is known to be as the last successful export left it. In any doubt
# (no fingerprint, unreadable DB) it is false and the DB is exported
function _db_unchanged() {
    local fingerprint

    fingerprint=$(_db_fingerprint 2>/dev/null) || return 1
    [ -n "${fingerprint}" ] && [ "${fingerprint}" = "$(cat "${EXPORTED_FILE}" 2>/dev/null)" ]
}

function _time_left() {
    echo $((EXPORT_TIMEOUT_SECS - SECONDS))
}

# Exports to file $1, for the pubkeys $2 (comma separated) or all of them. Returns 2 if the
# validator did not release the DB and 3 if the time budget ran out
function _export() {
    local output status attempt time_left

    for attempt in $(seq 1 "${LOCK_WAIT_ATTEMPTS}"); do
        time_left=$(_time_left)
        [ "${time_left}" -gt 0 ] || break

        # timeout stops Lodestar when the time budget runs out (SIGTERM, SIGKILL 5 s later)
        output=$(timeout --kill-after=5 "${time_left}" "${VALIDATOR_SERVICE_BIN}" validator slashing-protection export \
            --network="${NETWORK}" \
            --dataDir="${VALIDATOR_DATA_DIR}" \
            --file="${1}" \
            ${2:+--pubkeys="${2}"} 2>&1)
        status=$?
        [ "${status}" -eq 0 ] && return 0
        # The validator may still be stopping (e.g. `supervisorctl restart all` stops every
        # program at once): wait for it to release the DB lock
        [[ "${output}" == *"already in use"* ]] || break
        echo "${INFO} The validator still holds the DB, waiting for it to stop (${attempt}/${LOCK_WAIT_ATTEMPTS})"
        sleep 2
    done

    if [ "$(_time_left)" -le 0 ]; then
        echo "${ERROR} Lodestar slashing protection export did not finish within ${EXPORT_TIMEOUT_SECS} s, it was stopped"
        return 3
    fi

    # 137: killed, which without a timeout is the kernel out of memory killer
    echo "${ERROR} Lodestar slashing protection export failed (exit status ${status}):"
    echo "${output}" | tail -5
    [[ "${output}" == *"already in use"* ]] && return 2
    return 1
}

# Validators per file of a split export. Each file costs Lodestar a scan of the whole DB, which
# takes much longer than writing the records, so the fewer files the faster: as many validators
# as fit in SPLIT_FILE_SIZE_MB, going by the size per validator of the current interchange files
# (Lodestar writes one "pubkey" line per validator). SPLIT_VALIDATORS_PER_FILE if there are none
function _validators_per_file() {
    local bytes validators

    bytes=$(du -cb "${SLASHING_PROTECTION_DIR}"/interchange*.json 2>/dev/null | tail -1 | cut -f1)
    validators=$(cat "${SLASHING_PROTECTION_DIR}"/interchange*.json 2>/dev/null | grep -c '"pubkey"')

    if [ "${bytes:-0}" -gt 0 ] && [ "${validators:-0}" -gt 0 ]; then
        validators=$((SPLIT_FILE_SIZE_MB * 1024 * 1024 * validators / bytes))
        echo $((validators > 0 ? validators : 1))
    else
        echo "${SPLIT_VALIDATORS_PER_FILE}"
    fi
}

# Exports the pubkeys $1 (one per line) in files of $2 validators
function _export_files() {
    local pubkeys n=0

    echo "${INFO} Exporting in files of up to ${2} validators, for the validators with a keystore"
    rm -f "${TMP_DIR}"/*

    while read -r pubkeys; do
        n=$((n + 1))
        _export "${TMP_DIR}/interchange-${n}.json" "${pubkeys}" || return $?
    done < <(echo "${1}" | xargs -r -n "${2}" echo | tr ' ' ',')
}

# Exports the validators of the keystores in files of several validators each
function _export_split() {
    local pubkeys count size last_size=0 status=1

    pubkeys=$(find "${VALIDATOR_DATA_DIR}/keystores" -mindepth 1 -maxdepth 1 -type d -name '0x*' -printf '%f\n' 2>/dev/null | sort)
    if [ -z "${pubkeys}" ]; then
        echo "${ERROR} No validator keystore in ${VALIDATOR_DATA_DIR}/keystores to export by validator"
        return 1
    fi
    count=$(echo "${pubkeys}" | wc -l)

    # Fewer validators per file only when Lodestar failed, most likely on a file too big for it
    # (the validators do not have the same number of records, and they grow)
    for size in "$(_validators_per_file)" "${SPLIT_VALIDATORS_PER_FILE}" 1; do
        [ "${size}" -le "${count}" ] || size=${count}
        [ "${last_size}" -eq 0 ] || [ "${size}" -lt "${last_size}" ] || continue
        last_size=${size}
        _export_files "${pubkeys}" "${size}"
        status=$?
        [ "${status}" -eq 1 ] || break
    done

    return "${status}"
}

# Writes FAILED_FILE. $1: why the interchange files are stale, $2: date of the last successful
# export, if known
function _mark_stale() {
    local reason=$1 last_export=$2

    # After several failed exports in a row, the last successful one is in the previous marker
    [ -n "${last_export}" ] || last_export=$(sed -n 's/^last_successful_export=//p' "${FAILED_FILE}" 2>/dev/null)

    cat >"${FAILED_FILE}" <<EOF
The last export of the slashing protection DB of this cluster did not succeed.
The interchange files in this directory are STALE: they do not hold what the validators signed after the last successful export.
last_successful_export=${last_export:-never}
last_failed_export=$(date -u +%Y-%m-%dT%H:%M:%SZ)
reason=${reason}
EOF
}

# $1: why it failed
function _fail() {
    rm -rf "${TMP_DIR}"
    _mark_stale "${1}"

    echo "${ERROR} ################################################################"
    echo "${ERROR} Slashing protection export FAILED: ${1}"
    echo "${ERROR} ${SLASHING_PROTECTION_DIR} is NOT up to date (last successful export: $(sed -n 's/^last_successful_export=//p' "${FAILED_FILE}"))"
    echo "${ERROR} and a backup taken now would not protect the validators"
    echo "${ERROR} ################################################################"
    return 1
}

function export_slashing_protection() {
    local checksum fingerprint status last_export

    mkdir -p "${SLASHING_PROTECTION_DIR}"
    # Left behind only if a previous export was killed
    rm -rf "${TMP_DIR}"

    if [ ! -d "${VALIDATOR_DB_DIR}" ]; then
        echo "${INFO} No slashing protection DB, the validator has not run in this cluster"
        return 0
    fi

    if compgen -G "${SLASHING_PROTECTION_DIR}/interchange*.json" >/dev/null; then
        # A restored backup puts its own interchange files here: keep them until the validator imports them
        if [ "$(_interchange_checksum)" != "$(cat "${SYNCED_FILE}" 2>/dev/null)" ]; then
            echo "${INFO} ${SLASHING_PROTECTION_DIR} is not imported yet, it is kept until the validator starts and imports it"
            return 0
        fi

        # Nothing can have changed: the validator has not run since the last export (unused
        # cluster, or stopped while still waiting for Charon)
        if _db_unchanged; then
            rm -f "${FAILED_FILE}"
            echo "${INFO} The slashing protection DB has not been opened since the last export, ${SLASHING_PROTECTION_DIR} is up to date"
            return 0
        fi
    fi

    echo "${INFO} Exporting slashing protection DB to ${SLASHING_PROTECTION_DIR}"
    # The files are marked as stale until the export succeeds, so an export that is killed
    # leaves the mark too
    last_export=$(date -u -r "${EXPORTED_FILE}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    _mark_stale "it was interrupted before it finished (killed, or the host went down)" "${last_export}"
    rm -f "${EXPORTED_FILE}"
    mkdir -p "${TMP_DIR}"

    if [ "$(du -sm "${VALIDATOR_DB_DIR}" | cut -f1)" -gt "${SPLIT_DB_SIZE_MB}" ]; then
        _export_split
        status=$?
    else
        _export "${TMP_DIR}/interchange.json"
        status=$?
        # Too big for one file (see SPLIT_DB_SIZE_MB), unless the validator still holds the DB
        # or there is no time left
        if [ "${status}" -eq 1 ]; then
            _export_split
            status=$?
        fi
    fi

    case "${status}" in
    0) ;;
    2)
        _fail "the validator did not release the DB"
        return 1
        ;;
    3)
        _fail "it did not finish within the time budget of ${EXPORT_TIMEOUT_SECS} s"
        return 1
        ;;
    *)
        _fail "the Lodestar export failed, see the logs of the cluster"
        return 1
        ;;
    esac

    # Taken right after the export, so that it is the DB the exported files were read from
    fingerprint=$(_db_fingerprint) || fingerprint=""

    # Replace the previous files. Interrupted here, the files do not match SYNCED_FILE and are
    # imported (again) on the next start, which is harmless
    rm -f "${SLASHING_PROTECTION_DIR}"/interchange*.json
    mv "${TMP_DIR}"/interchange*.json "${SLASHING_PROTECTION_DIR}/"
    rm -rf "${TMP_DIR}"
    checksum=$(_interchange_checksum)
    echo "${checksum}" >"${SYNCED_FILE}"
    rm -f "${FAILED_FILE}"
    # Last: without it the next stop exports again
    echo "${fingerprint}" >"${EXPORTED_FILE}"
    echo "${INFO} Slashing protection exported: $(cd "${SLASHING_PROTECTION_DIR}" && echo interchange*.json)"
}

export_slashing_protection
