#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR=$(dirname "$0")

"$SCRIPT_DIR/wait-for-charon.sh"
"$SCRIPT_DIR/keystore-import.sh"
"$SCRIPT_DIR/sign-exit.sh"
"$SCRIPT_DIR/run-validator.sh"
