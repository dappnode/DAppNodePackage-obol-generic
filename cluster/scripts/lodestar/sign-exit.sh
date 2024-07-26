#!/bin/bash

INFO="[ INFO | lodestar-sign-exit ]"
ERROR="[ ERROR | lodestar-sign-exit ]"

function sign_exit() {

    if [ "$SIGN_EXIT" != true ]; then
        echo "${INFO} Signing exit is disabled. Skipping..."
        return 0
    fi

    # Validate exit epoch
    if [ -n "$EXIT_EPOCH" ]; then

        if [[ "$EXIT_EPOCH" =~ ^[0-9]+$ ]] && [ "$EXIT_EPOCH" -ge 1 ]; then
            echo "${INFO} Signing exit with EXIT_EPOCH=${EXIT_EPOCH}"
        else
            echo "${ERROR} EXIT_EPOCH is not valid. It must be a positive integer."
            return 1
        fi

    else
        echo "${INFO} Signing exit without EXIT_EPOCH"
    fi

    _sign_exit_lodestar
}

function _sign_exit_lodestar() {

    local flags="validator \
        voluntary-exit \
        --beaconNodes=http://localhost:3600 \
        --dataDir=${VALIDATOR_DATA_DIR} \
        --network=${NETWORK} \
        --yes"

    if [ -n "$EXIT_EPOCH" ]; then
        flags="${flags} --exitEpoch=${EXIT_EPOCH}"
    fi

    # shellcheck disable=SC2086
    ${VALIDATOR_SERVICE_BIN} ${flags}
}

sign_exit
