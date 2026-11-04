#!/bin/bash

set -euo pipefail

# User self-installation entry point. Builds an optimized Release app, signs it
# with a stable local "Mon Dev" identity, installs it in /Applications, and
# relaunches it. This is local trust, not Developer ID distribution signing.

identity_name=${MON_INSTALL_SIGN_IDENTITY:-Mon Dev}
install_path=${MON_INSTALL_PATH:-/Applications/Mon.app}
archive_app=build/Mon.xcarchive/Products/Applications/Mon.app
run_after_install=true

case ${1:-} in
    "") ;;
    --no-run) run_after_install=false ;;
    *)
        echo "usage: $0 [--no-run]" >&2
        exit 64
        ;;
esac

MON_LOCAL_SIGN_IDENTITY="$identity_name" Scripts/release-pipeline.sh local

if [[ ! -d "$archive_app" ]]; then
    echo "missing release app: $archive_app" >&2
    exit 1
fi

resolved_install_path=$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$install_path")
if [[ "$resolved_install_path" != "/Applications/Mon.app" && -z ${MON_INSTALL_PATH:-} ]]; then
    echo "refusing unexpected install path: $resolved_install_path" >&2
    exit 1
fi

if [[ -e "$install_path" ]]; then
    backup_dir=build/app-backups
    backup_path="$backup_dir/Mon-$(date -u +%Y%m%dT%H%M%SZ).app"
    mkdir -p "$backup_dir"
    ditto "$install_path" "$backup_path"
    echo "backed up existing app: $backup_path"
fi

osascript -e 'tell application id "com.totoleo.Mon" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf "$install_path"
ditto "$archive_app" "$install_path"
codesign --verify --deep --strict "$install_path"

echo "installed Mon: $install_path"
echo "signing identity: $identity_name"

if [[ "$run_after_install" == true ]]; then
    open "$install_path"
    echo "relaunched Mon"
fi
