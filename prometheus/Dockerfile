
ARG PROMETHEUS_VERSION

FROM prom/prometheus:${PROMETHEUS_VERSION}

ENV TEMPLATE_CONFIG_FILE=/etc/prometheus/prometheus_template.yml \
    CONFIG_FILE=/etc/prometheus/prometheus.yml

COPY prometheus_template.yml /etc/prometheus/

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

USER root

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]