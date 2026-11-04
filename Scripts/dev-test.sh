#!/bin/bash

set -euo pipefail

# Local-development only. xcodebuild test normally launches an unsigned test
# host whose changing code identity can make macOS request Accessibility again.
# This script builds without launching, re-signs the host with Amethyst Dev,
# then runs the already-built tests. Use a dedicated CI runner for CI tests.

derived_data_path=${AMETHYST_DEV_TEST_DERIVED_DATA:-build/DevTestDerivedData}
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
result_bundle_path=${AMETHYST_DEV_TEST_RESULT_BUNDLE:-build/dev-test-evidence/$timestamp.xcresult}
app_path=$derived_data_path/Build/Products/Debug/Amethyst.app

mkdir -p "$(dirname "$result_bundle_path")"
if [[ -e "$result_bundle_path" ]]; then
    echo "result bundle path already exists: $result_bundle_path" >&2
    exit 1
fi

xcodebuild \
    -workspace Amethyst.xcworkspace \
    -scheme Amethyst \
    -testPlan Amethyst \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived_data_path" \
    -onlyUsePackageVersionsFromResolvedFile \
    build-for-testing \
    ARCHS=arm64 \
    CODE_SIGNING_ALLOWED=NO

Scripts/bootstrap-dev-signing.sh >/dev/null
Scripts/sign-dev-app.sh "$app_path"

xcodebuild \
    -workspace Amethyst.xcworkspace \
    -scheme Amethyst \
    -testPlan Amethyst \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived_data_path" \
    -onlyUsePackageVersionsFromResolvedFile \
    -resultBundlePath "$result_bundle_path" \
    test-without-building \
    "$@"

echo "development tests completed with stable test host: $result_bundle_path"
