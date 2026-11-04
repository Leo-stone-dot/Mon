#!/bin/bash

set -euo pipefail

if [[ $# -ne 3 || ! -f "$1" ]]; then
    echo "usage: $0 ARCHIVE SPARKLE_ED_SIGNATURE SPARKLE_PUBLIC_KEY" >&2
    exit 64
fi

archive_path=$1
signature=$2
public_key=$3
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-sparkle-public-verify.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

public_key_base64=$temporary_directory/public-key.b64
public_key_bytes=$temporary_directory/public-key.bin
public_key_der=$temporary_directory/public-key.der
signature_base64=$temporary_directory/signature.b64
signature_bytes=$temporary_directory/signature.bin

printf '%s' "$public_key" > "$public_key_base64"
printf '%s' "$signature" > "$signature_base64"

if ! openssl base64 -d -A -in "$public_key_base64" -out "$public_key_bytes" 2>/dev/null; then
    echo "SPARKLE_PUBLIC_KEY is not valid base64" >&2
    exit 1
fi
if ! openssl base64 -d -A -in "$signature_base64" -out "$signature_bytes" 2>/dev/null; then
    echo "Sparkle EdDSA signature is not valid base64" >&2
    exit 1
fi

public_key_size=$(wc -c < "$public_key_bytes" | tr -d ' ')
signature_size=$(wc -c < "$signature_bytes" | tr -d ' ')
if [[ "$public_key_size" != "32" ]]; then
    echo "SPARKLE_PUBLIC_KEY must decode to a 32-byte Ed25519 public key" >&2
    exit 1
fi
if [[ "$signature_size" != "64" ]]; then
    echo "Sparkle EdDSA signature must decode to 64 bytes" >&2
    exit 1
fi

# SubjectPublicKeyInfo DER prefix for a raw 32-byte Ed25519 public key.
printf '\060\052\060\005\006\003\053\145\160\003\041\000' > "$public_key_der"
cat "$public_key_bytes" >> "$public_key_der"

if ! openssl pkeyutl -verify -pubin -inkey "$public_key_der" -keyform DER -rawin -in "$archive_path" -sigfile "$signature_bytes" > /dev/null 2>&1; then
    echo "Sparkle EdDSA signature does not verify with SPARKLE_PUBLIC_KEY" >&2
    exit 1
fi

echo "Sparkle archive public-key verification: ok"
