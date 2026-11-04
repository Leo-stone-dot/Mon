#!/bin/bash

set -euo pipefail

mode=${1:-ci}
archive_path=build/Mon.xcarchive
app_path=$archive_path/Products/Applications/Mon.app
manifest_path=build/release-manifest.json
final_zip=build/Mon-macos27-arm64.zip
notary_zip=build/Mon-notary-submit.zip
notary_result=build/notary-result.json

require_env() {
    local name=$1
    if [[ -z ${!name:-} ]]; then
        echo "missing required environment variable: $name" >&2
        exit 64
    fi
}

sign_bundle() {
    local bundle_path=$1
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$bundle_path"
}

sign_nested_code() {
    while IFS= read -r nested_bundle; do
        sign_bundle "$nested_bundle"
    done < <(
        find "$app_path" -depth -type d \
            \( -name "*.app" -o -name "*.xpc" -o -name "*.framework" \) \
            ! -path "$app_path" \
            | sort
    )

    codesign \
        --force \
        --options runtime \
        --timestamp \
        --entitlements Mon/Mon.entitlements \
        --sign "$DEVELOPER_ID_APPLICATION" \
        "$app_path"
}

sign_local_release() {
    local identity_name=${MON_LOCAL_SIGN_IDENTITY:-Mon Dev}

    SIGN_IDENTITY="$identity_name" Scripts/bootstrap-dev-signing.sh "$identity_name" >/dev/null
    SIGN_IDENTITY="$identity_name" Scripts/sign-dev-app.sh "$app_path"
    codesign --verify --deep --strict "$app_path"
    Scripts/generate-artifact-manifest.sh "$app_path" "$manifest_path"
}

notarize_and_staple() {
    ditto -c -k --keepParent "$app_path" "$notary_zip"
    xcrun notarytool submit "$notary_zip" \
        --keychain-profile "$NOTARYTOOL_PROFILE" \
        --wait \
        --output-format json \
        | tee "$notary_result"

    local status
    status=$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("status")' "$notary_result")
    if [[ "$status" != "Accepted" ]]; then
        echo "notarization failed with status: $status" >&2
        exit 1
    fi

    local submission_id
    submission_id=$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("id")' "$notary_result")
    export AMETHYST_NOTARIZATION_SUBMISSION_ID=$submission_id

    xcrun stapler staple "$app_path"
    xcrun stapler validate "$app_path"
}

case "$mode" in
    ci|unsigned)
        # `unsigned` remains as a temporary compatibility alias.
        Scripts/ci-archive.sh
        echo "CI release gates complete: $manifest_path"
        ;;
    local)
        Scripts/ci-archive.sh
        sign_local_release
        echo "local self-install archive complete: $app_path"
        ;;
    signed)
        Scripts/release-preflight.sh
        Scripts/ci-archive.sh
        Scripts/release-preflight.sh --post-archive
        sign_nested_code
        notarize_and_staple
        Scripts/verify-signed-release-artifact.sh "$app_path"
        ditto -c -k --keepParent "$app_path" "$final_zip"
        Scripts/generate-artifact-manifest.sh "$app_path" "$manifest_path" "$final_zip"
        echo "signed distribution pipeline complete: $final_zip"
        ;;
    *)
        echo "usage: $0 [ci|local|signed]" >&2
        exit 64
        ;;
esac
