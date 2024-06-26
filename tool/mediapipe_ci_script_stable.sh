#!/bin/bash

set -e

DIR="${BASH_SOURCE%/*}"
source "$DIR/ci_script_shared.sh"

flutter doctor -v

declare -ar PACKAGE_NAMES=(
    "mediapipe-core"
    "mediapipe-task-text"
)

ci_package "stable" "${PACKAGE_NAMES[@]}"

echo "-- Success --"
