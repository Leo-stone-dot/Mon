#!/bin/bash

set -euo pipefail

valid_public_key='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

expect_exit() {
    local expected_code=$1
    local name=$2
    shift 2

    local output
    local actual_code
    set +e
    output=$("$@" 2>&1)
    actual_code=$?
    set -e

    if [[ "$actual_code" -ne "$expected_code" ]]; then
        echo "expected exit $expected_code for $name, got $actual_code" >&2
        printf '%s\n' "$output" >&2
        exit 1
    fi

    EXPECTED_OUTPUT=$output
}

unset DEVELOPER_ID_APPLICATION NOTARYTOOL_PROFILE SPARKLE_SIGN_UPDATE SPARKLE_ED_KEY_FILE SPARKLE_PUBLIC_KEY AMETHYST_APPCAST_PATH || true

expect_exit 64 "missing DEVELOPER_ID_APPLICATION" Scripts/release-preflight.sh
rg -q 'missing required environment variable: DEVELOPER_ID_APPLICATION' <<< "$EXPECTED_OUTPUT"

set +e
DEVELOPER_ID_APPLICATION='Developer ID Application: Definitely Missing' \
NOTARYTOOL_PROFILE='definitely-missing-notary-profile' \
SPARKLE_SIGN_UPDATE='/usr/bin/true' \
SPARKLE_ED_KEY_FILE='build/definitely-missing-sparkle-key' \
SPARKLE_PUBLIC_KEY='not-base64' \
AMETHYST_APPCAST_PATH='build/definitely-missing-appcast.xml' \
Scripts/release-preflight.sh > /tmp/amethyst-release-preflight-test.out 2>&1
actual_code=$?
set -e

if [[ "$actual_code" -ne 1 ]]; then
    echo "expected exit 1 for malformed SPARKLE_PUBLIC_KEY, got $actual_code" >&2
    cat /tmp/amethyst-release-preflight-test.out >&2
    exit 1
fi

rg -q 'SPARKLE_PUBLIC_KEY must be a base64-encoded 32-byte Ed25519 public key' /tmp/amethyst-release-preflight-test.out

set +e
DEVELOPER_ID_APPLICATION='Developer ID Application: Definitely Missing' \
NOTARYTOOL_PROFILE='definitely-missing-notary-profile' \
SPARKLE_SIGN_UPDATE='/usr/bin/true' \
SPARKLE_ED_KEY_FILE='build/definitely-missing-sparkle-key' \
SPARKLE_PUBLIC_KEY="$valid_public_key" \
AMETHYST_APPCAST_PATH='build/definitely-missing-appcast.xml' \
Scripts/release-preflight.sh > /tmp/amethyst-release-preflight-test.out 2>&1
actual_code=$?
set -e

if [[ "$actual_code" -ne 1 ]]; then
    echo "expected exit 1 for missing signing identity, got $actual_code" >&2
    cat /tmp/amethyst-release-preflight-test.out >&2
    exit 1
fi

rg -q 'Developer ID signing identity not found' /tmp/amethyst-release-preflight-test.out
rm -f /tmp/amethyst-release-preflight-test.out

echo "release preflight self-test: ok"
