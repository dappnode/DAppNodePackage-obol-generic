#!/bin/bash

#############
# VARIABLES #
#############
ERROR="[ ERROR | charon-manager ]"
INFO="[ INFO | charon-manager ]"

CREATE_ENR_FILE=${CHARON_ROOT_DIR}/create_enr.txt
ENR_PRIVATE_KEY_FILE=${CHARON_ROOT_DIR}/charon-enr-private-key
ENR_FILE=${CHARON_ROOT_DIR}/enr
DEFINITION_FILE_URL_FILE=${CHARON_ROOT_DIR}/definition_file_url.txt

CHARON_LOCK_FILE=${CHARON_ROOT_DIR}/cluster-lock.json

if [ -n "$DEFINITION_FILE_URL" ]; then
    echo "$DEFINITION_FILE_URL" >$DEFINITION_FILE_URL_FILE
fi

export CHARON_P2P_EXTERNAL_HOSTNAME=${_DAPPNODE_GLOBAL_DOMAIN}

# To use staker scripts
# shellcheck disable=SC1091
. /etc/profile

#############
# FUNCTIONS #
#############

function get_beacon_node_endpoint() {
    local supported_networks="mainnet holesky"
    local local_beacon_api

    local_beacon_api=$(get_beacon_api_url_from_global_env "$NETWORK" "$supported_networks")

    if [ -n "$CUSTOM_BEACON_NODE_URLS" ]; then

        if [ -n "$local_beacon_api" ]; then
            CHARON_BEACON_NODE_ENDPOINTS="$CHARON_BEACON_NODE_ENDPOINTS,$local_beacon_api"
        else
            CHARON_BEACON_NODE_ENDPOINTS=$CUSTOM_BEACON_NODE_URLS
        fi

    else
        CHARON_BEACON_NODE_ENDPOINTS=$local_beacon_api
    fi

    echo "${INFO} Beacon node endpoints: $CHARON_BEACON_NODE_ENDPOINTS"

    export CHARON_BEACON_NODE_ENDPOINTS
}

# Get the ENR of the node or create it if it does not exist
function get_ENR() {
    # Check if ENR file exists and create it if it does not
    if [[ ! -f "$ENR_PRIVATE_KEY_FILE" ]]; then
        echo "${INFO} ENR does not exist, creating it..."
        if ! charon create enr --data-dir=${CHARON_ROOT_DIR} | tee ${CREATE_ENR_FILE}; then
            echo "${ERROR} Failed to create ENR."
            exit 1
        fi
    fi

    echo "${INFO} Storing ENR to file..."
    ENR=$(charon enr --data-dir=${CHARON_ROOT_DIR})
    echo "[INFO] ENR: ${ENR}"
    echo "${ENR}" >$ENR_FILE

    echo "${INFO} Publishing ENR to dappmanager..."
    post_ENR_to_dappmanager
}

# function to be post the ENR to dappmanager
function post_ENR_to_dappmanager() {
    # Post ENR to dappmanager
    curl --connect-timeout 5 \
        --max-time 10 \
        --silent \
        --retry 5 \
        --retry-delay 0 \
        --retry-max-time 40 \
        -X POST "http://my.dappnode/data-send?key=ENR%20Cluster%20${CLUSTER_ID}&data=${ENR}" ||
        {
            echo "[ERROR] failed to post ENR to dappmanager"
        }
}

function check_DKG() {
    # If the definition file URL is set and the lock file does not exist, start DKG ceremony
    if [ -n "${DEFINITION_FILE_URL}" ] && [ ! -f "${CHARON_LOCK_FILE}" ]; then
        echo "${INFO} Waiting for DKG ceremony..."
        charon dkg --definition-file="${DEFINITION_FILE_URL}" --data-dir="${CHARON_ROOT_DIR}" || {
            echo "${ERROR} DKG ceremony failed"
            exit 1
        }

    # If the definition file URL is not set and the lock file does not exist, wait for the definition file URL to be set
    elif [ -z "${DEFINITION_FILE_URL}" ] && [ ! -f "${CHARON_LOCK_FILE}" ]; then
        echo "${INFO} Set the definition file URL in the Charon config to start DKG ceremony..."
        sleep 1h # To let the user restore a backup
        exit 0

    else
        echo "${INFO} DKG ceremony already done. Process can continue..."
    fi
}

function run_charon() {
    if [ "$ENABLE_MEV_BOOST" = true ]; then
        CHARON_EXTRA_OPTS="--builder-api $CHARON_EXTRA_OPTS"
    fi

    exec charon run --private-key-file=$ENR_PRIVATE_KEY_FILE --lock-file=$CHARON_LOCK_FILE ${CHARON_EXTRA_OPTS}
}

########
# MAIN #
########

echo "${INFO} Getting the current beacon chain in use..."
get_beacon_node_endpoint

echo "${INFO} Getting the ENR..."
get_ENR

echo "${INFO} Checking for DKG ceremony..."
check_DKG

echo "${INFO} Triggering lodestar start..."
supervisorctl start lodestar

echo "${INFO} Starting charon..."
run_charon
