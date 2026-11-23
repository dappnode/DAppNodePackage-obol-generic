#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR=$(dirname "$0")

"$SCRIPT_DIR/wait-for-charon.sh"
"$SCRIPT_DIR/keystore-import.sh"
"$SCRIPT_DIR/slashing-protection-import.sh" || exit 1
"$SCRIPT_DIR/sign-exit.sh"
# exec so that supervisord supervises the validator itself and waits for it to exit when stopping it
exec "$SCRIPT_DIR/run-validator.sh"
