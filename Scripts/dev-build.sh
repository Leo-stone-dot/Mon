#!/bin/bash

set -euo pipefail

# Local-development only. Builds the Debug app, re-signs it with the stable
# development identity, and optionally relaunches it. Use this instead of
# launching the app from Xcode or Finder so macOS keeps the Accessibility
# (TCC) grant across rebuilds.

run_after_build=false
if [[ ${1:-} == "--run" ]]; then
    run_after_build=true
fi

xcodebuild \
    -workspace Amethyst.xcworkspace \
    -scheme Amethyst \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath build/DerivedData \
    -onlyUsePackageVersionsFromResolvedFile \
    build \
    ARCHS=arm64 \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    -quiet

Scripts/bootstrap-dev-signing.sh >/dev/null
Scripts/sign-dev-app.sh

if [[ "$run_after_build" == true ]]; then
    osascript -e 'tell application id "com.amethyst.Amethyst" to quit' >/dev/null 2>&1 || true
    sleep 1
    open build/DerivedData/Build/Products/Debug/Amethyst.app
    echo "relaunched Amethyst with the development-signed build"
fi
