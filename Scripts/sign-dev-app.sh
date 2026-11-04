#!/bin/bash

set -euo pipefail

# Signs an app with a local development identity created by
# Scripts/bootstrap-dev-signing.sh. Use it before testing Accessibility so the
# TCC grant survives rebuilds.

app_path=${1:-build/DerivedData/Build/Products/Debug/Mon.app}
identity_name=${SIGN_IDENTITY:-${AMETHYST_DEV_SIGN_IDENTITY:-Amethyst Dev}}

if [[ ! -d "$app_path" ]]; then
    echo "missing app bundle: $app_path" >&2
    exit 1
fi

codesign \
    --force \
    --deep \
    --sign "$identity_name" \
    --identifier com.totoleo.Mon \
    --timestamp=none \
    "$app_path"

codesign -dv --verbose=2 "$app_path" 2>&1 | rg 'Identifier=|Authority='
echo "signed app: $app_path ($identity_name)"
