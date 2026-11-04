#!/bin/bash

set -euo pipefail

project_file=Mon.xcodeproj/project.pbxproj

deployment_count=$(rg -c 'MACOSX_DEPLOYMENT_TARGET = 26\.0;' "$project_file")
architecture_count=$(rg -c 'ARCHS = arm64;' "$project_file")

if [[ "$deployment_count" -ne 6 ]]; then
    echo "expected 6 macOS 26.0 deployment settings; found $deployment_count" >&2
    exit 1
fi

if [[ "$architecture_count" -ne 6 ]]; then
    echo "expected 6 arm64 architecture settings; found $architecture_count" >&2
    exit 1
fi

if rg -n 'MACOSX_DEPLOYMENT_TARGET = (10\.|1[12](;|\.)|2[0-5]\.)' "$project_file"; then
    echo "found a deployment target below macOS 26.0" >&2
    exit 1
fi

if rg -n 'swiftlint --fix' "$project_file"; then
    echo "Xcode build phase must not modify source" >&2
    exit 1
fi

if rg -n 'kind = branch|"branch"|LoginServiceKit|loginservicekit' "$project_file" Mon.xcworkspace/xcshareddata/swiftpm/Package.resolved; then
    echo "found an unpinned branch or removed LoginServiceKit dependency" >&2
    exit 1
fi

if rg -n 'LSSharedFileList|SUUpdater' Mon; then
    echo "found a removed legacy system or updater API" >&2
    exit 1
fi

rg -q 'macOS 26 or later on Apple silicon' README.md
rg -q 'LSMinimumSystemVersion' Mon/Mon-Info.plist
rg -q 'MACOSX_DEPLOYMENT_TARGET=26\.0' docs/macos-27-support-policy.md
rg -q 'macOS 26\.0' docs/macos-27-support-policy.md
rg -q 'minimum system version is 26\.0' docs/macos-27-validation-checklist.md

if rg -n 'macOS 27 or later|macOS 27\+|MACOSX_DEPLOYMENT_TARGET=27\.0' \
    README.md docs/macos-27-adaptation-plan.md docs/macos-27-support-policy.md docs/macos-27-support.md docs/macos-27-validation-checklist.md; then
    echo "found a stale macOS 27.0 support-floor claim" >&2
    exit 1
fi

echo "support contract: macOS 26.0+, arm64 only"
