#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR=$(dirname "$0")

# Execute the scripts with paths relative to the script directory
"$SCRIPT_DIR/handle-file-import.sh"
"$SCRIPT_DIR/run-charon.sh"
