#!/bin/bash

INFO="[ INFO | lodestar-keystore-import ]"

function import_keystores_to_lodestar() {

    local charon_keys_dir=${CHARON_ROOT_DIR}/validator_keys

    local validator_keys_dir=${VALIDATOR_DATA_DIR}/keystores
    local validator_secrets_dir=${VALIDATOR_DATA_DIR}/secrets

    mkdir -p "${validator_keys_dir}" "${validator_secrets_dir}"

    local imported_count=0
    local existing_count=0

    for f in "${charon_keys_dir}"/keystore-*.json; do
        local pubkey
        local pubkey_dir
        local password_file

        echo "$INFO Importing key ${f}"

        # Extract pubkey from keystore file
        pubkey="0x$(grep '"pubkey"' "$f" | awk -F'"' '{print $4}')"
        pubkey_dir="${validator_keys_dir}/${pubkey}"

        # Skip import if keystore already exists
        if [[ -d "${pubkey_dir}" ]]; then
            existing_count=$((existing_count + 1))
            continue
        fi

        mkdir -p "${pubkey_dir}"

        # Copy the keystore file to persisted keys backend
        install -m 600 "$f" "${pubkey_dir}/voting-keystore.json"

        # Copy the corresponding password file
        password_file="${f//json/txt}"
        install -m 600 "${password_file}" "${validator_secrets_dir}/${pubkey}"

        imported_count=$((imported_count + 1))
    done

    echo "$INFO Processed all keys imported=${imported_count}, existing=${existing_count}, total=$(ls ${charon_keys_dir}/keystore-*.json | wc -l)"
}

import_keystores_to_lodestar
