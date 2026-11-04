#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
    echo "usage: $0 APP_BUNDLE" >&2
    exit 64
fi

app_path=$1
minimum_system_version=$(plutil -extract LSMinimumSystemVersion raw "$app_path/Contents/Info.plist")

if [[ "$minimum_system_version" != "26.0" ]]; then
    echo "expected minimum system version 26.0; found $minimum_system_version" >&2
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

codesign --verify --deep --strict --verbose=2 "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
xcrun stapler validate "$app_path"

echo "signed release artifact verified"
