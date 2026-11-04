#!/bin/bash

set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 || ! -d "$1" || ! -d "$2" ]]; then
    echo "usage: $0 APP_BUNDLE ARCHIVES_DIRECTORY DOWNLOAD_URL_PREFIX [RELEASE_NOTES_URL_PREFIX] [CHANNEL]" >&2
    exit 64
fi

app_path=$1
archives_directory=$2
download_url_prefix=$3
release_notes_url_prefix=${4:-}
channel=${5:-}
info_plist=$app_path/Contents/Info.plist
appcast_path=$archives_directory/appcast.xml

require_env() {
    local name=$1
    if [[ -z ${!name:-} ]]; then
        echo "missing required environment variable: $name" >&2
        exit 64
    fi
}

require_env SPARKLE_GENERATE_APPCAST
require_env SPARKLE_ED_KEY_FILE

if [[ ! -f "$info_plist" ]]; then
    echo "missing app Info.plist: $info_plist" >&2
    exit 1
fi
if [[ ! -x "$SPARKLE_GENERATE_APPCAST" ]]; then
    echo "missing executable Sparkle generate_appcast: $SPARKLE_GENERATE_APPCAST" >&2
    exit 1
fi
if [[ ! -f "$SPARKLE_ED_KEY_FILE" ]]; then
    echo "missing Sparkle EdDSA private key file: $SPARKLE_ED_KEY_FILE" >&2
    exit 1
fi
if [[ "$download_url_prefix" != https://* ]]; then
    echo "download URL prefix must use HTTPS" >&2
    exit 1
fi
if [[ -n "$release_notes_url_prefix" && "$release_notes_url_prefix" != https://* ]]; then
    echo "release notes URL prefix must use HTTPS" >&2
    exit 1
fi

public_key=$(plutil -extract SUPublicEDKey raw "$info_plist" 2>/dev/null || true)
if [[ -z "$public_key" ]]; then
    echo "missing SUPublicEDKey in app Info.plist" >&2
    exit 1
fi
Scripts/verify-sparkle-key-pair.sh "$SPARKLE_ED_KEY_FILE" "$public_key"

build=$(plutil -extract CFBundleVersion raw "$info_plist")
arguments=(
    "$SPARKLE_GENERATE_APPCAST"
    --ed-key-file "$SPARKLE_ED_KEY_FILE"
    --download-url-prefix "$download_url_prefix"
    --versions "$build"
    --maximum-versions 0
    --maximum-deltas 0
    -o "$appcast_path"
)

if [[ -n "$release_notes_url_prefix" ]]; then
    arguments+=(--release-notes-url-prefix "$release_notes_url_prefix")
fi
if [[ -n "$channel" ]]; then
    arguments+=(--channel "$channel")
fi

"${arguments[@]}" "$archives_directory"
Scripts/verify-appcast.sh "$appcast_path" "$app_path"

echo "prepared appcast: $appcast_path"
