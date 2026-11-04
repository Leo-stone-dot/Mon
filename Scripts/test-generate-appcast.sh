#!/bin/bash

set -euo pipefail

sparkle_generate_appcast=${SPARKLE_GENERATE_APPCAST:-}
if [[ -z "$sparkle_generate_appcast" ]]; then
    for candidate in \
        build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast \
        build/DerivedData/SourcePackages/checkouts/Sparkle/bin/generate_appcast
    do
        if [[ -x "$candidate" ]]; then
            sparkle_generate_appcast=$candidate
            break
        fi
    done
fi

if [[ -z "$sparkle_generate_appcast" || ! -x "$sparkle_generate_appcast" ]]; then
    echo "missing Sparkle generate_appcast; set SPARKLE_GENERATE_APPCAST or resolve Sparkle artifacts first" >&2
    exit 1
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-generate-appcast-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

app_path=$temporary_directory/Amethyst.app
info_plist=$app_path/Contents/Info.plist
archives_directory=$temporary_directory/archives
private_key=$temporary_directory/private-key.b64
wrong_private_key=$temporary_directory/wrong-private-key.b64
mkdir -p "$app_path/Contents" "$archives_directory"

openssl genpkey -algorithm ED25519 -out "$temporary_directory/key.pem" >/dev/null 2>&1
openssl pkey -in "$temporary_directory/key.pem" -outform DER 2>/dev/null \
    | tail -c 32 \
    | base64 > "$private_key"
openssl pkey -in "$temporary_directory/key.pem" -pubout -outform DER 2>/dev/null \
    | tail -c 32 \
    | base64 \
    | tr -d '\n' > "$temporary_directory/public-key.b64"
openssl genpkey -algorithm ED25519 -out "$temporary_directory/wrong-key.pem" >/dev/null 2>&1
openssl pkey -in "$temporary_directory/wrong-key.pem" -outform DER 2>/dev/null \
    | tail -c 32 \
    | base64 > "$wrong_private_key"

plutil -create xml1 "$info_plist"
plutil -insert CFBundleIdentifier -string "com.amethyst.generate-appcast-test" "$info_plist"
plutil -insert CFBundleShortVersionString -string "1.0" "$info_plist"
plutil -insert CFBundleVersion -string "10" "$info_plist"
plutil -insert LSMinimumSystemVersion -string "26.0" "$info_plist"
plutil -insert SUPublicEDKey -string "$(< "$temporary_directory/public-key.b64")" "$info_plist"
ditto -c -k --keepParent "$app_path" "$archives_directory/Amethyst-1.0.zip"
printf '<!DOCTYPE html><html><body>Release notes</body></html>\n' > "$archives_directory/Amethyst-1.0.html"

expect_failure() {
    local name=$1
    shift

    if "$@" > /dev/null 2>&1; then
        echo "expected failure: $name" >&2
        exit 1
    fi
}

expect_failure "non-HTTPS download URL" env \
    SPARKLE_GENERATE_APPCAST="$sparkle_generate_appcast" \
    SPARKLE_ED_KEY_FILE="$private_key" \
    Scripts/generate-appcast.sh "$app_path" "$archives_directory" "http://example.com/downloads/"
expect_failure "mismatched private key" env \
    SPARKLE_GENERATE_APPCAST="$sparkle_generate_appcast" \
    SPARKLE_ED_KEY_FILE="$wrong_private_key" \
    Scripts/generate-appcast.sh "$app_path" "$archives_directory" "https://example.com/downloads/"

SPARKLE_GENERATE_APPCAST="$sparkle_generate_appcast" \
SPARKLE_ED_KEY_FILE="$private_key" \
Scripts/generate-appcast.sh \
    "$app_path" \
    "$archives_directory" \
    "https://example.com/downloads/" \
    "https://example.com/release-notes/"

Scripts/verify-appcast.sh "$archives_directory/appcast.xml" "$app_path"

ruby -rrexml/document - "$archives_directory/appcast.xml" <<'RUBY'
document = REXML::Document.new(File.read(ARGV.fetch(0)))
items = document.get_elements("//item")
abort "expected one generated appcast item" unless items.length == 1
enclosure = items.first.elements["enclosure"]
abort "missing EdDSA signature" if enclosure.attributes["sparkle:edSignature"].to_s.empty?
abort "wrong archive URL" unless enclosure.attributes["url"] == "https://example.com/downloads/Amethyst-1.0.zip"
archive_path = File.join(File.dirname(ARGV.fetch(0)), "Amethyst-1.0.zip")
abort "wrong archive length" unless enclosure.attributes["length"] == File.size(archive_path).to_s
abort "wrong release notes URL" unless items.first.elements["sparkle:releaseNotesLink"].text == "https://example.com/release-notes/Amethyst-1.0.html"
RUBY

generated_signature=$(ruby -rrexml/document - "$archives_directory/appcast.xml" <<'RUBY'
document = REXML::Document.new(File.read(ARGV.fetch(0)))
print document.get_elements("//item").first.elements["enclosure"].attributes["sparkle:edSignature"]
RUBY
)
Scripts/verify-sparkle-archive-public-key.sh \
    "$archives_directory/Amethyst-1.0.zip" \
    "$generated_signature" \
    "$(< "$temporary_directory/public-key.b64")" > /dev/null

SPARKLE_GENERATE_APPCAST="$sparkle_generate_appcast" \
SPARKLE_ED_KEY_FILE="$private_key" \
Scripts/generate-appcast.sh \
    "$app_path" \
    "$archives_directory" \
    "https://example.com/downloads/" \
    "https://example.com/release-notes/"

ruby -rrexml/document - "$archives_directory/appcast.xml" <<'RUBY'
document = REXML::Document.new(File.read(ARGV.fetch(0)))
abort "regeneration duplicated the build" unless document.get_elements("//item").length == 1
RUBY

echo "appcast generation self-test: ok"
