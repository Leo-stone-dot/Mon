#!/bin/bash

set -euo pipefail

timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
output_dir=${1:-build/physical-validation/$timestamp}
mkdir -p "$output_dir"

capture() {
    local name=$1
    shift
    {
        printf '$'
        printf ' %q' "$@"
        printf '\n\n'
        "$@"
    } > "$output_dir/$name" 2>&1 || {
        local exit_code=$?
        printf '\n[exit %s]\n' "$exit_code" >> "$output_dir/$name"
        return 0
    }
}

capture_text() {
    local name=$1
    shift
    {
        printf '$'
        printf ' %q' "$@"
        printf '\n\n'
        "$@"
    } > "$output_dir/$name" 2>&1 || true
}

capture sw_vers.txt sw_vers
capture uname.txt uname -a
capture architecture.txt uname -m
capture xcode.txt xcodebuild -version
capture sdk-version.txt xcrun --sdk macosx --show-sdk-version
capture sdk-path.txt xcrun --sdk macosx --show-sdk-path
capture hardware.txt system_profiler SPHardwareDataType
capture displays.txt system_profiler SPDisplaysDataType
capture git-commit.txt git rev-parse HEAD
capture git-status.txt git status --short
capture package-resolved-sha256.txt shasum -a 256 Mon.xcworkspace/xcshareddata/swiftpm/Package.resolved

if [[ -f build/release-manifest.json ]]; then
    cp build/release-manifest.json "$output_dir/release-manifest.json"
    capture release-manifest-sha256.txt shasum -a 256 build/release-manifest.json
fi

if [[ -d build/Mon.xcarchive/Products/Applications/Mon.app ]]; then
    app_path=build/Mon.xcarchive/Products/Applications/Mon.app
    capture app-info.txt plutil -p "$app_path/Contents/Info.plist"
    {
        while IFS= read -r candidate; do
            if file "$candidate" | rg -q 'Mach-O'; then
                printf '%s: %s\n' "$candidate" "$(lipo -archs "$candidate")"
            fi
        done < <(find "$app_path" -type f)
    } > "$output_dir/app-architectures.txt"
fi

{
    echo "# macOS defaults relevant to Spaces and Stage Manager"
    echo
    echo "## com.apple.spaces spans-displays"
    defaults read com.apple.spaces spans-displays 2>&1 || true
    echo
    echo "## com.apple.dock workspaces-auto-swoosh"
    defaults read com.apple.dock workspaces-auto-swoosh 2>&1 || true
    echo
    echo "## com.apple.WindowManager GloballyEnabled"
    defaults read com.apple.WindowManager GloballyEnabled 2>&1 || true
    echo
    echo "## com.apple.WindowManager EnableStandardClickToShowDesktop"
    defaults read com.apple.WindowManager EnableStandardClickToShowDesktop 2>&1 || true
} > "$output_dir/spaces-stage-manager-defaults.txt"

for candidate_app in \
    build/Mon.xcarchive/Products/Applications/Mon.app \
    build/DerivedData/Build/Products/Debug/Mon.app \
    build/DerivedData/Build/Products/Release/Mon.app
do
    executable=$candidate_app/Contents/MacOS/Mon
    if [[ -x "$executable" ]]; then
        "$executable" --debug-info > "$output_dir/debug-info.txt" 2>&1 || true
        break
    fi
done

preflight_status=0
Scripts/verify-physical-runner.sh > "$output_dir/physical-runner-preflight.txt" 2>&1 || preflight_status=$?

product_version=$(sw_vers -productVersion)
build_version=$(sw_vers -buildVersion)
architecture=$(uname -m)
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
xcode_version=$(xcodebuild -version | tr '\n' ' ' | sed 's/[[:space:]]*$//')
model_identifier=$(system_profiler SPHardwareDataType | awk -F ': ' '/Model Identifier/ { print $2; exit }')
chip=$(system_profiler SPHardwareDataType | awk -F ': ' '/Chip/ { print $2; exit }')
commit=$(git rev-parse HEAD)

cat > "$output_dir/session.md" <<EOF
# macOS 27 Physical Validation Evidence

- Timestamp (UTC): $timestamp
- Git commit: $commit
- Machine model: ${model_identifier:-unknown}
- Chip: ${chip:-unknown}
- Architecture: $architecture
- macOS: $product_version ($build_version)
- Xcode: $xcode_version
- SDK: $sdk_version
- Physical preflight status: $preflight_status

## Evidence Files

- sw_vers.txt
- uname.txt
- architecture.txt
- xcode.txt
- sdk-version.txt
- sdk-path.txt
- hardware.txt
- displays.txt
- spaces-stage-manager-defaults.txt
- debug-info.txt
- physical-runner-preflight.txt
- git-commit.txt
- git-status.txt
- package-resolved-sha256.txt

## Manual Fields Required Before Approval

- RC version/build:
- Artifact SHA-256:
- Separate Spaces:
- Stage Manager:
- Mission Control animation settings:
- Accessibility permission state at start:
- Tester:
- Scenario result logs/screenshots:

## Result

This evidence directory is a collection bundle. It is release-blocking runtime
evidence only when \`physical-runner-preflight.txt\` passes on a macOS 27.2
physical Apple silicon runner and the scenario checklist is completed.
EOF

echo "physical validation evidence: $output_dir"
if [[ "$preflight_status" -ne 0 ]]; then
    echo "physical runner preflight failed; see $output_dir/physical-runner-preflight.txt" >&2
    exit "$preflight_status"
fi
