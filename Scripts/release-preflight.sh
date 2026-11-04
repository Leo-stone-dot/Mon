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

require_env DEVELOPER_ID_APPLICATION
require_env NOTARYTOOL_PROFILE

if ! security find-identity -v -p codesigning | rg -F "$DEVELOPER_ID_APPLICATION" >/dev/null; then
    echo "Developer ID signing identity not found: $DEVELOPER_ID_APPLICATION" >&2
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE" --output-format json >/dev/null; then
    echo "notarytool keychain profile is unavailable or invalid: $NOTARYTOOL_PROFILE" >&2
    exit 1
fi

if [[ "$mode" == "--post-archive" && ! -d "$app_path" ]]; then
    echo "missing archived app: $app_path" >&2
    exit 1
fi

echo "release preflight: ok"
