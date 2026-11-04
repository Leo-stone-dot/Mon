#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 || ! -d "$1" ]]; then
    echo "usage: $0 APP_BUNDLE SPARKLE_PUBLIC_KEY" >&2
    exit 64
fi

app_path=$1
public_key=$2
info_plist=$app_path/Contents/Info.plist

if [[ ! -f "$info_plist" ]]; then
    echo "missing Info.plist: $info_plist" >&2
    exit 1
fi

public_key_bytes=$(printf '%s' "$public_key" | openssl base64 -d -A 2>/dev/null | wc -c | tr -d ' ')
if [[ "$public_key_bytes" != "32" ]]; then
    echo "SPARKLE_PUBLIC_KEY must be a base64-encoded 32-byte Ed25519 public key" >&2
    exit 1
fi

plutil -remove SUPublicEDKey "$info_plist" >/dev/null 2>&1 || true
plutil -insert SUPublicEDKey -string "$public_key" "$info_plist"

echo "injected SUPublicEDKey into $info_plist"
