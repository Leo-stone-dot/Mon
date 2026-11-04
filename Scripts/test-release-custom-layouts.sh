#!/bin/bash

set -euo pipefail

derived_data_path=${AMETHYST_RELEASE_CUSTOM_LAYOUT_DERIVED_DATA:-build/ReleaseCustomLayoutValidation}
source_packages_path=${AMETHYST_SOURCE_PACKAGES_PATH:-build/DerivedData/SourcePackages}
if [[ -n ${AMETHYST_RELEASE_CUSTOM_LAYOUT_RESULT_BUNDLE:-} ]]; then
    result_bundle_path=$AMETHYST_RELEASE_CUSTOM_LAYOUT_RESULT_BUNDLE
else
    result_bundle_path="build/release-custom-layout-evidence/release-custom-layout-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
fi

if [[ ! -d "$source_packages_path" ]]; then
    echo "missing resolved source packages: $source_packages_path; run Scripts/ci-build-and-test.sh first" >&2
    exit 1
fi

release_settings=$(xcodebuild \
    -showBuildSettings \
    -workspace Mon.xcworkspace \
    -scheme Mon \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    ARCHS=arm64 \
    CODE_SIGNING_ALLOWED=NO)

grep -q 'CODE_SIGN_ENTITLEMENTS = Mon/Mon.entitlements' <<< "$release_settings"
grep -q 'ENABLE_HARDENED_RUNTIME = YES' <<< "$release_settings"
if [[ "$(plutil -extract 0 raw Mon/Mon.entitlements 2>/dev/null || true)" != "" ]]; then
    echo "Release entitlements must remain empty" >&2
    exit 1
fi

mkdir -p "$(dirname "$result_bundle_path")"
if [[ -e "$result_bundle_path" ]]; then
    echo "result bundle path already exists: $result_bundle_path" >&2
    exit 1
fi

xcodebuild \
    -workspace Mon.xcworkspace \
    -scheme Mon \
    -testPlan Mon \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived_data_path" \
    -clonedSourcePackagesDirPath "$source_packages_path" \
    -onlyUsePackageVersionsFromResolvedFile \
    -only-testing:MonTests/CustomLayoutTests \
    -resultBundlePath "$result_bundle_path" \
    clean test \
    ARCHS=arm64 \
    CODE_SIGNING_ALLOWED=NO \
    ENABLE_TESTABILITY=YES

echo "Release custom layout tests: ok"
