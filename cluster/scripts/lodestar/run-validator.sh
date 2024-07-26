#!/bin/bash

INFO="[ INFO | lodestar-validator ]"

function run_lodestar_validator() {

    local flags="validator \
        --network=${NETWORK} \
        --dataDir=${VALIDATOR_DATA_DIR} \
        --beaconNodes=http://localhost:3600 \
        --metrics=true \
        --metrics.address=0.0.0.0 \
        --metrics.port=${VALIDATOR_METRICS_PORT} \
        --graffiti=${GRAFFITI} \
        --suggestedFeeRecipient=${DEFAULT_FEE_RECIPIENT} \
        --distributed"

    if [ "$ENABLE_MEV_BOOST" = true ]; then
        VALIDATOR_EXTRA_OPTS="--builder=true --builder.selection=builderonly $VALIDATOR_EXTRA_OPTS"
    fi

    if [ -n "$VALIDATOR_EXTRA_OPTS" ]; then
        flags="${flags} ${VALIDATOR_EXTRA_OPTS}"
    fi

    echo "${INFO} Starting Lodestar validator with flags: ${flags}"

    # shellcheck disable=SC2086
    exec ${VALIDATOR_SERVICE_BIN} ${flags}
}

run_lodestar_validator
