#!/bin/bash

set -euo pipefail

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "Xcode 27 gate requires an arm64 runner" >&2
    exit 1
fi

macos_major=$(sw_vers -productVersion | cut -d . -f 1)
if [[ "$macos_major" -lt 26 ]]; then
    echo "unit tests for a macOS 26 deployment target require a macOS 26+ runner" >&2
    exit 1
fi

if [[ "$(xcrun --sdk macosx --show-sdk-version)" != "27.2" ]]; then
    echo "Xcode 27 gate requires the macOS 27.2 SDK" >&2
    exit 1
fi

xcodebuild \
    -resolvePackageDependencies \
    -workspace Mon.xcworkspace \
    -scheme Mon \
    -onlyUsePackageVersionsFromResolvedFile

set -o pipefail
xcodebuild \
    -workspace Mon.xcworkspace \
    -scheme Mon \
    -testPlan Mon \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData \
    -onlyUsePackageVersionsFromResolvedFile \
    clean test \
    ARCHS=arm64 \
    CODE_SIGNING_ALLOWED=NO \
    | mint run xcbeautify
