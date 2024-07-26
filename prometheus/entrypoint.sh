#!/bin/sh

# These envs are defined in the compose file: MONITORING_URL, MONITORING_CREDENTIALS, ACTIVE_CHARONS_NUMBER

if [ -z "$MONITORING_URL" ] || [ -z "$MONITORING_CREDENTIALS" ]; then
    echo "MONITORING_URL and MONITORING_CREDENTIALS must be set in the config to enable monitoring"
    exit 0 # To avoid restart
fi

if [ -z "$CHARONS_TO_MONITOR" ]; then
    echo "CHARONS_TO_MONITOR must be set to a comma-separated array of numbers like: 1,2,3"
    exit 0 # To avoid restart
fi

if [ "$CHARONS_TO_MONITOR" = "0" ]; then
    echo "No charons to monitor, exiting..."
    exit 0 # To avoid restart
fi

# Normalize the input by removing spaces around commas and at the ends
CHARONS_TO_MONITOR=$(echo "$CHARONS_TO_MONITOR" | sed 's/ *, */,/g' | sed 's/^ *//;s/ *$//')

# Check that CHARONS_TO_MONITOR only contains numbers separated by commas
echo "$CHARONS_TO_MONITOR" | grep -E '^[0-9]+(,[0-9]+)*$' >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "CHARONS_TO_MONITOR must be a comma-separated list of numbers without spaces"
    exit 0 # To avoid restart
fi

# Generate charon and validator targets based on the normalized CHARONS_TO_MONITOR
IFS=','
for i in $CHARONS_TO_MONITOR; do
    if [ "$charon_targets" != "" ]; then
        charon_targets="$charon_targets, "
        validator_targets="$validator_targets, "
    fi
    charon_targets="${charon_targets}\"cluster-$i:3620\""
    validator_targets="${validator_targets}\"cluster-$i:8008\""
done

# Wrap the generated strings in brackets (arrays)
charon_targets="[$charon_targets]"
validator_targets="[$validator_targets]"

# Replace placeholders in the configuration template
sed -e "s|<MONITORING_URL>|$MONITORING_URL|g" \
    -e "s|<MONITORING_CREDENTIALS>|$MONITORING_CREDENTIALS|g" \
    -e "s|<CHARON_TARGETS>|$charon_targets|g" \
    -e "s|<VALIDATOR_TARGETS>|$validator_targets|g" \
    $TEMPLATE_CONFIG_FILE >$CONFIG_FILE

exec /bin/prometheus --config.file $CONFIG_FILE
