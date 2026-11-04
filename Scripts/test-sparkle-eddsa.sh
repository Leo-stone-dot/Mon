#!/bin/bash

set -euo pipefail

# Exercises the Sparkle EdDSA path without a production signing key:
# generate an ephemeral Ed25519 key, sign a test archive, verify it, prove
# tampering and wrong keys fail, and feed the real signature through the
# appcast gate.

sparkle_sign_update=${SPARKLE_SIGN_UPDATE:-}
if [[ -z "$sparkle_sign_update" ]]; then
    for candidate in \
        build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update \
        build/DerivedData/SourcePackages/checkouts/Sparkle/bin/sign_update
    do
        if [[ -x "$candidate" ]]; then
            sparkle_sign_update=$candidate
            break
        fi
    done
fi

if [[ -z "$sparkle_sign_update" || ! -x "$sparkle_sign_update" ]]; then
    echo "missing Sparkle sign_update; set SPARKLE_SIGN_UPDATE or resolve Sparkle artifacts first" >&2
    exit 1
fi

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-sparkle-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

generate_key() {
    local name=$1

    openssl genpkey -algorithm ED25519 -out "$temporary_directory/$name.pem" >/dev/null 2>&1
    openssl pkey -in "$temporary_directory/$name.pem" -outform DER 2>/dev/null \
        | tail -c 32 \
        | base64 > "$temporary_directory/$name-private-key.b64"
    openssl pkey -in "$temporary_directory/$name.pem" -pubout -outform DER 2>/dev/null \
        | tail -c 32 \
        | base64 > "$temporary_directory/$name-public-key.b64"

    local private_bytes public_bytes
    private_bytes=$(openssl base64 -d -A -in "$temporary_directory/$name-private-key.b64" | wc -c | tr -d ' ')
    public_bytes=$(openssl base64 -d -A -in "$temporary_directory/$name-public-key.b64" | wc -c | tr -d ' ')

    if [[ "$private_bytes" != "32" || "$public_bytes" != "32" ]]; then
        echo "unexpected Ed25519 key sizes for $name: private=$private_bytes public=$public_bytes" >&2
        exit 1
    fi
}

generate_key test
generate_key wrong
test_public_key=$(tr -d '\n' < "$temporary_directory/test-public-key.b64")
wrong_public_key=$(tr -d '\n' < "$temporary_directory/wrong-public-key.b64")

app_path=$temporary_directory/Amethyst.app
mkdir -p "$app_path/Contents"
info_plist=$app_path/Contents/Info.plist
plutil -create xml1 "$info_plist"
plutil -insert CFBundleShortVersionString -string "1.0" "$info_plist"
plutil -insert CFBundleVersion -string "10" "$info_plist"
plutil -insert LSMinimumSystemVersion -string "26.0" "$info_plist"

archive=$temporary_directory/Amethyst.zip
ditto -c -k --keepParent "$app_path" "$archive"

signature_output=$temporary_directory/signature.txt
"$sparkle_sign_update" \
    --ed-key-file "$temporary_directory/test-private-key.b64" \
    "$archive" > "$signature_output"

signature=$(ruby -e 'text = File.read(ARGV.fetch(0)); abort "missing signature" unless text =~ /sparkle:edSignature="([^"]+)"/; puts Regexp.last_match(1)' "$signature_output")
length=$(ruby -e 'text = File.read(ARGV.fetch(0)); abort "missing length" unless text =~ /\blength="([^"]+)"/; puts Regexp.last_match(1)' "$signature_output")

expect_success() {
    local name=$1
    shift

    if ! "$@" > /dev/null 2>&1; then
        echo "expected success: $name" >&2
        exit 1
    fi
}

expect_failure() {
    local name=$1
    shift

    if "$@" > /dev/null 2>&1; then
        echo "expected failure: $name" >&2
        exit 1
    fi
}

expect_success "signed archive verification" \
    "$sparkle_sign_update" --ed-key-file "$temporary_directory/test-private-key.b64" --verify "$archive" "$signature"
expect_success "public-key archive verification" \
    Scripts/verify-sparkle-archive-public-key.sh "$archive" "$signature" "$test_public_key"

tampered_archive=$temporary_directory/Amethyst-tampered.zip
cp "$archive" "$tampered_archive"
printf 'tamper' >> "$tampered_archive"

expect_failure "tampered archive" \
    "$sparkle_sign_update" --ed-key-file "$temporary_directory/test-private-key.b64" --verify "$tampered_archive" "$signature"
expect_failure "tampered archive public-key verification" \
    Scripts/verify-sparkle-archive-public-key.sh "$tampered_archive" "$signature" "$test_public_key"

expect_failure "wrong key" \
    "$sparkle_sign_update" --ed-key-file "$temporary_directory/wrong-private-key.b64" --verify "$archive" "$signature"

expect_failure "wrong signature" \
    "$sparkle_sign_update" --ed-key-file "$temporary_directory/test-private-key.b64" --verify "$archive" "${signature%??}AA"
expect_failure "wrong public key" \
    Scripts/verify-sparkle-archive-public-key.sh "$archive" "$signature" "$wrong_public_key"

write_appcast() {
    local path=$1
    local ed_signature=$2

    cat > "$path" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Amethyst</title>
    <item>
      <title>Amethyst 1.0</title>
      <sparkle:releaseNotesLink>https://example.com/release-notes.html</sparkle:releaseNotesLink>
      <enclosure url="https://example.com/Amethyst.zip" sparkle:version="10" sparkle:shortVersionString="1.0" sparkle:minimumSystemVersion="26.0" sparkle:edSignature="$ed_signature" sparkle:length="$length" />
    </item>
  </channel>
</rss>
XML
}

valid_appcast=$temporary_directory/valid.xml
write_appcast "$valid_appcast" "$signature"
expect_success "appcast gate with real EdDSA signature" \
    Scripts/verify-appcast.sh "$valid_appcast" "$app_path" "$signature_output"

tampered_appcast=$temporary_directory/tampered.xml
write_appcast "$tampered_appcast" "AAAA"
expect_failure "appcast gate with mismatched EdDSA signature" \
    Scripts/verify-appcast.sh "$tampered_appcast" "$app_path" "$signature_output"

echo "Sparkle EdDSA self-test: ok"
