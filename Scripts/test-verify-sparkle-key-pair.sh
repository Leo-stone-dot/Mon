#!/bin/bash

set -euo pipefail

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-sparkle-key-pair-test.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

generate_key() {
    local name=$1

    openssl genpkey -algorithm ED25519 -out "$temporary_directory/$name.pem" >/dev/null 2>&1
    openssl pkey -in "$temporary_directory/$name.pem" -outform DER 2>/dev/null \
        | tail -c 32 \
        | base64 > "$temporary_directory/$name-private-key.b64"
    openssl pkey -in "$temporary_directory/$name.pem" -pubout -outform DER 2>/dev/null \
        | tail -c 32 \
        | base64 \
        | tr -d '\n' > "$temporary_directory/$name-public-key.b64"
}

expect_failure() {
    local name=$1
    shift

    if "$@" > /dev/null 2>&1; then
        echo "expected failure: $name" >&2
        exit 1
    fi
}

generate_key matching
generate_key mismatched

matching_public_key=$(< "$temporary_directory/matching-public-key.b64")
mismatched_public_key=$(< "$temporary_directory/mismatched-public-key.b64")

Scripts/verify-sparkle-key-pair.sh "$temporary_directory/matching-private-key.b64" "$matching_public_key" > /dev/null
expect_failure "mismatched key pair" \
    Scripts/verify-sparkle-key-pair.sh "$temporary_directory/matching-private-key.b64" "$mismatched_public_key"
expect_failure "malformed public key" \
    Scripts/verify-sparkle-key-pair.sh "$temporary_directory/matching-private-key.b64" "not-base64"

printf 'not-base64' > "$temporary_directory/malformed-private-key.b64"
expect_failure "malformed private key" \
    Scripts/verify-sparkle-key-pair.sh "$temporary_directory/malformed-private-key.b64" "$matching_public_key"

echo "Sparkle EdDSA key pair self-test: ok"
