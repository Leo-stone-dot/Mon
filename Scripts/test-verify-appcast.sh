#!/bin/bash

set -euo pipefail

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-appcast-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

app_path=$temporary_directory/Amethyst.app
mkdir -p "$app_path/Contents"
info_plist=$app_path/Contents/Info.plist

plutil -create xml1 "$info_plist"
plutil -insert CFBundleShortVersionString -string "1.0" "$info_plist"
plutil -insert CFBundleVersion -string "10" "$info_plist"
plutil -insert LSMinimumSystemVersion -string "26.0" "$info_plist"

signature_output=$temporary_directory/signature.txt
printf 'sparkle:edSignature="signature-value" sparkle:length="123"\n' > "$signature_output"

write_appcast() {
    local path=$1
    local enclosure_url=$2
    local minimum_system_version=$3
    local ed_signature=$4
    local length=$5
    local short_version=$6
    local build=$7

    cat > "$path" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Amethyst</title>
    <item>
      <title>Amethyst $short_version</title>
      <sparkle:releaseNotesLink>https://example.com/release-notes.html</sparkle:releaseNotesLink>
      <enclosure url="$enclosure_url" sparkle:version="$build" sparkle:shortVersionString="$short_version" sparkle:minimumSystemVersion="$minimum_system_version" sparkle:edSignature="$ed_signature" sparkle:length="$length" />
    </item>
  </channel>
</rss>
XML
}

expect_success() {
    local name=$1
    local appcast_path=$2

    if ! Scripts/verify-appcast.sh "$appcast_path" "$app_path" "$signature_output" > /dev/null; then
        echo "expected appcast gate to pass: $name" >&2
        exit 1
    fi
}

expect_failure() {
    local name=$1
    local appcast_path=$2

    if Scripts/verify-appcast.sh "$appcast_path" "$app_path" "$signature_output" > /dev/null 2>&1; then
        echo "expected appcast gate to fail: $name" >&2
        exit 1
    fi
}

valid_appcast=$temporary_directory/valid.xml
write_appcast "$valid_appcast" "https://example.com/Amethyst.zip" "26.0" "signature-value" "123" "1.0" "10"
expect_success "valid appcast" "$valid_appcast"

missing_signature_appcast=$temporary_directory/missing-signature.xml
write_appcast "$missing_signature_appcast" "https://example.com/Amethyst.zip" "26.0" "" "123" "1.0" "10"
expect_failure "missing edSignature" "$missing_signature_appcast"

non_https_appcast=$temporary_directory/non-https.xml
write_appcast "$non_https_appcast" "http://example.com/Amethyst.zip" "26.0" "signature-value" "123" "1.0" "10"
expect_failure "non-HTTPS enclosure" "$non_https_appcast"

wrong_minimum_appcast=$temporary_directory/wrong-minimum.xml
write_appcast "$wrong_minimum_appcast" "https://example.com/Amethyst.zip" "25.0" "signature-value" "123" "1.0" "10"
expect_failure "wrong minimumSystemVersion" "$wrong_minimum_appcast"

wrong_version_appcast=$temporary_directory/wrong-version.xml
write_appcast "$wrong_version_appcast" "https://example.com/Amethyst.zip" "26.0" "signature-value" "123" "2.0" "20"
expect_failure "version mismatch" "$wrong_version_appcast"

wrong_signature_appcast=$temporary_directory/wrong-signature.xml
write_appcast "$wrong_signature_appcast" "https://example.com/Amethyst.zip" "26.0" "different-signature" "123" "1.0" "10"
expect_failure "signature mismatch" "$wrong_signature_appcast"

wrong_length_appcast=$temporary_directory/wrong-length.xml
write_appcast "$wrong_length_appcast" "https://example.com/Amethyst.zip" "26.0" "signature-value" "456" "1.0" "10"
expect_failure "length mismatch" "$wrong_length_appcast"

echo "appcast gate self-test: ok"
