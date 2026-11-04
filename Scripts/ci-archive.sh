#!/bin/bash

set -euo pipefail

archive_path=build/Amethyst.xcarchive
app_path=$archive_path/Products/Applications/Amethyst.app

xcodebuild \
    -workspace Amethyst.xcworkspace \
    -scheme Amethyst \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive_path" \
    -derivedDataPath build/DerivedData \
    -onlyUsePackageVersionsFromResolvedFile \
    -quiet \
    archive \
    ARCHS=arm64 \
    CODE_SIGNING_ALLOWED=NO

Scripts/thin-archive.sh "$app_path"

minimum_system_version=$(plutil -extract LSMinimumSystemVersion raw "$app_path/Contents/Info.plist")
if [[ "$minimum_system_version" != "26.0" ]]; then
    echo "expected archive minimum system version 26.0; found $minimum_system_version" >&2
    exit 1
fi

while IFS= read -r candidate; do
    if file "$candidate" | rg -q 'Mach-O'; then
        architectures=$(lipo -archs "$candidate")
        if [[ "$architectures" != "arm64" ]]; then
            echo "expected arm64-only Mach-O: $candidate ($architectures)" >&2
            exit 1
        fi
    fi
done < <(find "$app_path" -type f)

echo "archive contract: LSMinimumSystemVersion=26.0, Mach-O architecture=arm64"
Scripts/generate-artifact-manifest.sh "$app_path" build/release-manifest.json
