#!/bin/bash

set -euo pipefail

# Local-development only. Re-signs the Debug app with the stable development
# identity created by Scripts/bootstrap-dev-signing.sh. Run this after each
# Debug build before testing Accessibility behavior, so the TCC grant survives
# rebuilds.

app_path=${1:-build/DerivedData/Build/Products/Debug/Mon.app}
identity_name=${AMETHYST_DEV_SIGN_IDENTITY:-Amethyst Dev}

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
echo "signed development app: $app_path"
