#!/bin/bash

set -euo pipefail

require_exact_line() {
    local file=$1
    local expected=$2
    if ! rg -qx --fixed-strings "$expected" "$file"; then
        echo "expected exact lock entry in $file: $expected" >&2
        exit 1
    fi
}

require_exact_line Brewfile 'brew "mint"'
require_exact_line Brewfile 'brew "ruby@3.4"'
require_exact_line Mintfile 'realm/SwiftLint@0.65.1'
require_exact_line Mintfile 'cpisciotta/xcbeautify@3.2.1'
require_exact_line Gemfile 'gem "fastlane", "2.241.2"'
require_exact_line Gemfile.lock '  fastlane (= 2.241.2)'
require_exact_line Gemfile.lock '    fastlane (2.241.2)'

if ! rg -F 'brew bundle install --no-upgrade' Scripts/bootstrap-tools.sh >/dev/null; then
    echo "bootstrap must not upgrade Brewfile dependencies" >&2
    exit 1
fi
if ! rg -F 'bundle install --frozen' Scripts/bootstrap-tools.sh >/dev/null; then
    echo "bootstrap must install the locked Gemfile without resolution changes" >&2
    exit 1
fi
if rg -n 'swiftlint --fix' Mon.xcodeproj/project.pbxproj; then
    echo "Xcode build phases must not format source" >&2
    exit 1
fi

ruby -rjson - Mon.xcworkspace/xcshareddata/swiftpm/Package.resolved <<'RUBY'
lockfile = JSON.parse(File.read(ARGV.fetch(0)))
missing_revisions = lockfile.fetch("pins").select do |pin|
  pin.fetch("state").fetch("revision", "").empty?
end
abort "SwiftPM pins without revisions: #{missing_revisions.map { |pin| pin.fetch("identity") }.join(", ")}" unless missing_revisions.empty?
RUBY

echo "toolchain locks: Mint, Bundler, SwiftPM, and non-mutating build phase are pinned"
