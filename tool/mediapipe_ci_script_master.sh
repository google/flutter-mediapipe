#!/bin/bash

# set -e

DIR="${BASH_SOURCE%/*}"
source "$DIR/ci_script_shared.sh"

flutter doctor -v

declare -ar PACKAGE_NAMES=(
    # TODO(craiglabenz): Uncomment once native assets works on CI
    # "mediapipe-core"
    "mediapipe-task-text"
)

ci_package "master" "${PACKAGE_NAMES[@]}"

echo "-- Success --"
