#!/bin/bash

ERROR="[ ERROR | file-import-handler ]"
INFO="[ INFO | file-import-handler ]"

# Main function to handle Charon file import
function handle_charon_file_import() {
    local import_file

    echo "${INFO} Starting Charon file import process in ${IMPORT_DIR}"
    if [ -n "${IMPORT_DIR}" ] && [ -d "${IMPORT_DIR}" ]; then

        echo "${INFO} Searching for .tar.gz, .tar.xz or .zip files in ${IMPORT_DIR}"
        import_file=$(_find_import_file)

        if [ -z "${import_file}" ]; then
            echo "${INFO} No file found in ${IMPORT_DIR}, or it is empty. No import process to be performed."
            return
        fi

        echo "${INFO} Found file to import: ${import_file}"
        _move_old_charon
        _extract_file_into_charon_dir "${import_file}"
        rm -f "${import_file}"
        _empty_lodestar_keys
        echo "${INFO} Import file processing complete."

    else
        echo "${ERROR} IMPORT_DIR is not set or does not exist. No import process to be performed."
    fi

    return 0
}

# Finds the first .tar.gz or .zip file in the IMPORT_DIR
function _find_import_file() {
    find "${IMPORT_DIR}" -type f \( -name "*.tar.gz" -o -name "*.zip" -o -name "*.tar.xz" \) | head -1
}

# Moves existing files in the .charon directory to a timestamped old-charon directory
function _move_old_charon() {
    local timestamp
    local old_charon_dir

    if [ -d "${CHARON_ROOT_DIR}" ] && [ "$(ls -A ${CHARON_ROOT_DIR})" ]; then

        timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
        old_charon_dir="/opt/charon/old-charons/${timestamp}"

        echo "${INFO} Moving existing files in ${CHARON_ROOT_DIR} to ${old_charon_dir}..."

        mkdir -p "${old_charon_dir}"
        mv ${CHARON_ROOT_DIR}/* "${old_charon_dir}"

    else
        echo "${INFO} No existing files found in ${CHARON_ROOT_DIR} to move."
    fi
}

# Extracts the import file into the .charon directory
function _extract_file_into_charon_dir() {
    echo "${INFO} Starting extraction of ${1} into ${CHARON_ROOT_DIR}"

    # Create a temporary directory for initial extraction
    tmp_dir=$(mktemp -d)

    # Extract the archive to the temporary directory
    if [[ "${1}" == *.tar.gz || "${1}" == *.tar.xz ]]; then
        tar --exclude='._*' -xvf "${1}" -C "${tmp_dir}" && echo "${INFO} Extraction (.tar.gz or .tar.xz format) to temporary directory complete."
    elif [[ "${1}" == *.zip ]]; then
        unzip -o "${1}" -d "${tmp_dir}" && echo "${INFO} Extraction (.zip format) to temporary directory complete."
    fi

    # Read contents of the temp directory into an array using mapfile
    mapfile -t contents < <(ls -A "${tmp_dir}")

    echo "${INFO} Moving files from temporary directory to ${CHARON_ROOT_DIR}..."

    if [[ ${#contents[@]} == 1 && -d "${tmp_dir}/${contents[0]}" ]]; then
        echo "${INFO} Found exactly one directory in the archive: ${contents[0]}"

        # If there is exactly one directory, move its contents to CHARON_ROOT_DIR
        mv "${tmp_dir}/${contents[0]}"/* "${CHARON_ROOT_DIR}"
        rmdir "${tmp_dir}/${contents[0]}" # Remove the now empty directory
    else
        echo "${INFO} Moving all files and directories from the temporary directory to ${CHARON_ROOT_DIR}"

        # Move all files and directories from the temp directory directly to CHARON_ROOT_DIR
        mv "${tmp_dir}"/* "${CHARON_ROOT_DIR}"
    fi

    echo "${INFO} Files moved to ${CHARON_ROOT_DIR}"

    # Cleanup the temporary directory
    rmdir "${tmp_dir}"
    echo "${INFO} Temporary directory cleaned up."
}

# Remove all keys from the validator service
function _empty_lodestar_keys() {
    echo "${INFO} Emptying validator service keys..."
    rm -rf "${VALIDATOR_DATA_DIR}"/cache/* "${VALIDATOR_DATA_DIR}"/keystores/* "${VALIDATOR_DATA_DIR}"/secrets/*
}

handle_charon_file_import
