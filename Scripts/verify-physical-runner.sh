#!/bin/bash

set -euo pipefail

product_version=$(sw_vers -productVersion)
build_version=$(sw_vers -buildVersion)
architecture=$(uname -m)
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
xcode_version=$(xcodebuild -version | head -n 1)
model_identifier=$(system_profiler SPHardwareDataType | awk -F ': ' '/Model Identifier/ { print $2; exit }')
chip=$(system_profiler SPHardwareDataType | awk -F ': ' '/Chip/ { print $2; exit }')

printf 'model=%s\nchip=%s\narchitecture=%s\nmacos=%s (%s)\n%s\nsdk=%s\n' \
    "$model_identifier" "$chip" "$architecture" "$product_version" "$build_version" "$xcode_version" "$sdk_version"

if [[ "$architecture" != "arm64" || "$product_version" != 27.2* || "$sdk_version" != "27.2" || "$xcode_version" != "Xcode 27.2" ]]; then
    echo "runner does not satisfy the macOS 27.2 physical gate" >&2
    exit 1
fi
