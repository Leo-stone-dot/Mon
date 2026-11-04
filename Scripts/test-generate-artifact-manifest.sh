#!/bin/bash

set -euo pipefail

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-manifest-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

app_path=$temporary_directory/Mon.app
info_plist=$app_path/Contents/Info.plist
archive_path=$temporary_directory/Mon.zip
manifest_path=$temporary_directory/manifest.json
mkdir -p "$app_path/Contents"

plutil -create xml1 "$info_plist"
plutil -insert CFBundleIdentifier -string "com.amethyst.manifest-test" "$info_plist"
plutil -insert CFBundleShortVersionString -string "1.0" "$info_plist"
plutil -insert CFBundleVersion -string "10" "$info_plist"
plutil -insert LSMinimumSystemVersion -string "26.0" "$info_plist"
ditto -c -k --keepParent "$app_path" "$archive_path"

Scripts/generate-artifact-manifest.sh "$app_path" "$manifest_path" "$archive_path" > /dev/null

ruby -rjson - "$manifest_path" "$archive_path" <<'RUBY'
require "digest"

manifest = JSON.parse(File.read(ARGV.fetch(0)))
archive_path = ARGV.fetch(1)
archive = manifest.fetch("archive")

abort "manifest archive path mismatch" unless archive.fetch("path") == archive_path
abort "manifest archive size mismatch" unless archive.fetch("bytes") == File.size(archive_path)
abort "manifest archive SHA-256 mismatch" unless archive.fetch("sha256") == Digest::SHA256.file(archive_path).hexdigest
dependencies = manifest.fetch("dependencies")
abort "manifest dependencies are empty" if dependencies.empty?
abort "manifest dependency has no revision" unless dependencies.all? { |dependency| dependency.fetch("revision").match?(/\A[0-9a-f]+\z/) }
RUBY

if Scripts/generate-artifact-manifest.sh "$app_path" "$manifest_path" "$temporary_directory/missing.zip" > /dev/null 2>&1; then
    echo "expected missing archive to fail" >&2
    exit 1
fi

echo "artifact manifest self-test: ok"
