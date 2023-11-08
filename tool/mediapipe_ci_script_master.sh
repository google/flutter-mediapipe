#!/bin/bash

set -e

DIR="${BASH_SOURCE%/*}"
source "$DIR/ci_script_shared.sh"

flutter doctor -v

declare -ar PACKAGE_NAMES=(
    "mediapipe-core"
)

ci_package "master" "${PACKAGE_NAMES[@]}"

echo "-- Success --"
