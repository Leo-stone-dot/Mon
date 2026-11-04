#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 OUTPUT_DIRECTORY" >&2
    exit 64
fi

output_directory=$1
mkdir -p "$output_directory"

ruby_bin=$(brew --prefix ruby@3.4)/bin
export PATH="$ruby_bin:$PATH"

sw_vers > "$output_directory/macos.txt"
uname -m > "$output_directory/architecture.txt"
xcodebuild -version > "$output_directory/xcode.txt"
xcrun --sdk macosx --show-sdk-path > "$output_directory/sdk-path.txt"
xcrun --sdk macosx --show-sdk-version > "$output_directory/sdk-version.txt"
xcodebuild -workspace Mon.xcworkspace -scheme Mon -showBuildSettings > "$output_directory/build-settings.txt"
cp Mon.xcworkspace/xcshareddata/swiftpm/Package.resolved "$output_directory/Package.resolved"
git rev-parse HEAD > "$output_directory/commit.txt"

mint run swiftlint version > "$output_directory/swiftlint-version.txt"
mint run xcbeautify --version > "$output_directory/xcbeautify-version.txt"
BUNDLE_PATH=build/vendor/bundle bundle exec fastlane --version > "$output_directory/fastlane-version.txt"
