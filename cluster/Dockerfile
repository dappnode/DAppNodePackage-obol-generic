ARG CHARON_VERSION
FROM obolnetwork/charon:${CHARON_VERSION}

ARG CLUSTER_ID
ARG VALIDATOR_CLIENT_VERSION
ARG NETWORK
ARG P2P_TCP_PORT
ARG P2P_UDP_PORT

USER root

RUN apt-get update && \
    apt-get --yes --no-install-recommends install curl jq zip xz-utils inotify-tools supervisor && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p /opt/validator/bin /usr/local/bin/scripts/charon /usr/local/bin/scripts/lodestar && \
    curl -L https://github.com/ChainSafe/lodestar/releases/download/${VALIDATOR_CLIENT_VERSION}/lodestar-${VALIDATOR_CLIENT_VERSION}-linux-amd64.tar.gz | tar -xz -C /opt/validator/bin && \
    chmod +x /opt/validator/bin/lodestar

COPY scripts /usr/local/bin/scripts
COPY supervisord.conf /etc/supervisord.conf

ENV CLUSTER_ID=${CLUSTER_ID} \
    CHARON_LOG_FORMAT=console \
    VALIDATOR_SERVICE_BIN=/opt/validator/bin/lodestar \
    VALIDATOR_DATA_DIR=/opt/validator/data \
    VALIDATOR_METRICS_PORT=8008 \
    CHARON_VALIDATOR_API_ADDRESS="0.0.0.0:3600" \
    CHARON_MONITORING_ADDRESS="0.0.0.0:3620" \
    CHARON_ROOT_DIR=/opt/charon/.charon \
    IMPORT_DIR=/import/ \
    SUPERVISOR_DIR=/opt/supervisor \
    STAKER_SCRIPTS_URL=https://github.com/dappnode/staker-package-scripts/releases/download/${STAKER_SCRIPTS_VERSION}

ADD ${STAKER_SCRIPTS_URL}/consensus_tools.sh /etc/profile.d/

RUN mkdir -p ${CHARON_ROOT_DIR} ${VALIDATOR_DATA_DIR} ${IMPORT_DIR} ${SUPERVISOR_DIR} && \
    chown -R charon:charon /opt/charon && \
    chmod +x /usr/local/bin/scripts/**/* && \
    chmod +rx /etc/profile.d/consensus_tools.sh

# To import here the artifacts from file manager by default
WORKDIR /import

# Placed here to regenerate less layers
ENV NETWORK=${NETWORK} \
    CHARON_P2P_TCP_ADDRESS="0.0.0.0:${P2P_TCP_PORT}" \
    CHARON_P2P_UDP_ADDRESS="0.0.0.0:${P2P_UDP_PORT}"

# Use supervisord to start services
ENTRYPOINT ["supervisord", "-c", "/etc/supervisord.conf"]