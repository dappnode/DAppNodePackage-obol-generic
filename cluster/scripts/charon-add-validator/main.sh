#!/bin/bash

# VARS
SERVICE_OK=0
ATTEMPTS=0
MAX_ATTEMPTS=10
INFO="[ INFO | container-add-validator:]"

# Function that runs the validator addition logic
run_validator_logic() {
    echo "${INFO} Add validators for $CHARON_SERVICE_NAME"

    # Check if ADD_VALIDATOR is setting in config for current running service
    if [[ "$ADD_VALIDATOR_TARGET_CLUSTER" =~ (^|,)($CHARON_SERVICE_NAME)(,|$) ]]; then
        echo "${INFO} Start running charon add-validators command"

        charon alpha add-validators \
            --data-dir="$CHARON_ROOT_DIR" \
            --num-validators "$ADD_VALIDATOR_NUM_VALIDATORS" \
            --withdrawal-addresses="$ADD_VALIDATOR_WITHDRAWAL_ADDRESS" \
            --fee-recipient-addresses="$ADD_VALIDATOR_FEE_RECEPIENT_ADDRESS" \
            --p2p-relays https://4.relay.obol.dev \
            --output-dir=/tmp/.charon

        if [[ $? -ne 0 ]]; then
            echo "${INFO} charon add-validators failed. Exiting..."
            rm -f /import/add_validator
            rm -rf /tmp/.charon
            exit 1
        fi

        echo "${INFO} Stopping charon and lodestar during upgrade processes..."
        supervisorctl stop charon lodestar

        echo "${INFO} Upgrade .charon directory with backing up previous .charon to /tmp/.charon"
        cp -r "$CHARON_ROOT_DIR" /tmp/.charon.bck && mv /tmp/.charon "$CHARON_ROOT_DIR"

        echo "${INFO} Starting charon and lodestar processes..."
        supervisorctl start charon lodestar

        while [[ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]]; do
            if supervisorctl status charon | grep -q "RUNNING"; then
                SERVICE_OK=1
                break
            fi

            echo "${INFO} charon not ready, waiting 2 seconds... (Attempt ${ATTEMPTS}/${MAX_ATTEMPTS})"
            sleep 3
            ATTEMPTS=$((ATTEMPTS + 1))
        done

        if [[ "$SERVICE_OK" -eq 1 ]]; then
            echo "${INFO} Validator(s) added, charon is running."
            touch "$CHARON_ROOT_DIR/.charon_added_validator_state"
        else
            echo "${INFO} Validator(s) was not added, restoring .charon state folder to previous one and restart cluster. Check logs for more details"
            mv /tmp/.charon.bck "$CHARON_ROOT_DIR"
            supervisorctl restart charon lodestar
        fi
    fi
}

# Watch for the creation of /import/add_validator and trigger logic
inotifywait -m /import -e create |
while read path action file; do
    if [ "$file" == "add_validator" ]; then
        echo "${INFO} Trigger file detected, executing validator logic..."
        run_validator_logic
        rm -f /import/add_validator
    fi
done
