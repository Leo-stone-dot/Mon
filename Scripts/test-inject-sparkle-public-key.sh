#!/bin/bash

set -euo pipefail

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-sparkle-key-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

app_path=$temporary_directory/Amethyst.app
info_plist=$app_path/Contents/Info.plist
mkdir -p "$app_path/Contents"
plutil -create xml1 "$info_plist"
plutil -insert CFBundleShortVersionString -string "1.0" "$info_plist"
plutil -insert CFBundleVersion -string "10" "$info_plist"
plutil -insert LSMinimumSystemVersion -string "26.0" "$info_plist"

first_key='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
second_key='AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE='

Scripts/inject-sparkle-public-key.sh "$app_path" "$first_key" > /dev/null
expect_value=$(plutil -extract SUPublicEDKey raw "$info_plist")
if [[ "$expect_value" != "$first_key" ]]; then
    echo "injected key did not match first key" >&2
    exit 1
fi

Scripts/inject-sparkle-public-key.sh "$app_path" "$second_key" > /dev/null
expect_value=$(plutil -extract SUPublicEDKey raw "$info_plist")
if [[ "$expect_value" != "$second_key" ]]; then
    echo "injected key did not replace the previous key" >&2
    exit 1
fi

if Scripts/inject-sparkle-public-key.sh "$app_path" 'not-base64' > /dev/null 2>&1; then
    echo "expected malformed key to fail" >&2
    exit 1
fi

if Scripts/inject-sparkle-public-key.sh "$temporary_directory/missing.app" "$first_key" > /dev/null 2>&1; then
    echo "expected missing Info.plist to fail" >&2
    exit 1
fi

echo "Sparkle public key injection self-test: ok"
