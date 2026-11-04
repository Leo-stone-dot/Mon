#!/bin/bash

set -euo pipefail

mode=${1:-pre-archive}
case "$mode" in
    pre-archive|--post-archive) ;;
    *)
        echo "usage: $0 [pre-archive|--post-archive]" >&2
        exit 64
        ;;
esac

archive_path=build/Amethyst.xcarchive
app_path=$archive_path/Products/Applications/Amethyst.app

require_env() {
    local name=$1
    if [[ -z ${!name:-} ]]; then
        echo "missing required environment variable: $name" >&2
        exit 64
    fi
}

require_file() {
    local path=$1
    local label=$2
    if [[ ! -f "$path" ]]; then
        echo "missing $label: $path" >&2
        exit 1
    fi
}

require_executable() {
    local path=$1
    local label=$2
    if [[ ! -x "$path" ]]; then
        echo "missing executable $label: $path" >&2
        exit 1
    fi
}

require_env DEVELOPER_ID_APPLICATION
require_env NOTARYTOOL_PROFILE
require_env SPARKLE_SIGN_UPDATE
require_env SPARKLE_ED_KEY_FILE
require_env SPARKLE_PUBLIC_KEY
require_env AMETHYST_APPCAST_PATH

public_key_bytes=$(printf '%s' "$SPARKLE_PUBLIC_KEY" | openssl base64 -d -A 2>/dev/null | wc -c | tr -d ' ')
if [[ "$public_key_bytes" != "32" ]]; then
    echo "SPARKLE_PUBLIC_KEY must be a base64-encoded 32-byte Ed25519 public key" >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | rg -F "$DEVELOPER_ID_APPLICATION" >/dev/null; then
    echo "Developer ID signing identity not found: $DEVELOPER_ID_APPLICATION" >&2
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE" --output-format json >/dev/null; then
    echo "notarytool keychain profile is unavailable or invalid: $NOTARYTOOL_PROFILE" >&2
    exit 1
fi

require_executable "$SPARKLE_SIGN_UPDATE" "Sparkle sign_update"
require_file "$SPARKLE_ED_KEY_FILE" "Sparkle EdDSA private key file"
require_file "$AMETHYST_APPCAST_PATH" "staging appcast"
Scripts/verify-sparkle-key-pair.sh "$SPARKLE_ED_KEY_FILE" "$SPARKLE_PUBLIC_KEY"

if [[ "$mode" == "--post-archive" ]]; then
    if [[ ! -d "$app_path" ]]; then
        echo "missing archived app: $app_path" >&2
        exit 1
    fi

    built_public_key=$(plutil -extract SUPublicEDKey raw "$app_path/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$built_public_key" != "$SPARKLE_PUBLIC_KEY" ]]; then
        echo "built Info.plist SUPublicEDKey does not match SPARKLE_PUBLIC_KEY" >&2
        exit 1
    fi
fi

echo "release preflight: ok"
