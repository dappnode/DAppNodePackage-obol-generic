#!/bin/bash

INFO="[ INFO | lodestar-wait ]"

# Wait for Charon to be ready
while true; do
    status_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3620/readyz)
    if [ "$status_code" -eq 200 ]; then
        echo "$INFO Charon is ready. Lodestar can start."
        break
    else
        echo "$INFO Waiting for Charon to be ready before launching lodestar..."
        sleep 60
    fi
done
