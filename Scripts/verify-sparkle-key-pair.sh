#!/bin/bash

set -euo pipefail

if [[ $# -ne 2 || ! -f "$1" ]]; then
    echo "usage: $0 SPARKLE_ED_PRIVATE_KEY_FILE SPARKLE_PUBLIC_KEY" >&2
    exit 64
fi

private_key_file=$1
public_key=$2
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/amethyst-sparkle-key-pair.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT

private_key_base64=$temporary_directory/private-key.b64
private_key_bytes=$temporary_directory/private-key.bin
public_key_base64=$temporary_directory/public-key.b64
public_key_bytes=$temporary_directory/public-key.bin
private_key_der=$temporary_directory/private-key.der
derived_public_key_der=$temporary_directory/derived-public-key.der
derived_public_key_bytes=$temporary_directory/derived-public-key.bin

cp "$private_key_file" "$private_key_base64"
printf '%s' "$public_key" > "$public_key_base64"

if ! openssl base64 -d -A -in "$private_key_base64" -out "$private_key_bytes" 2>/dev/null; then
    echo "Sparkle EdDSA private key is not valid base64" >&2
    exit 1
fi

if ! openssl base64 -d -A -in "$public_key_base64" -out "$public_key_bytes" 2>/dev/null; then
    echo "SPARKLE_PUBLIC_KEY is not valid base64" >&2
    exit 1
fi

private_key_size=$(wc -c < "$private_key_bytes" | tr -d ' ')
public_key_size=$(wc -c < "$public_key_bytes" | tr -d ' ')
if [[ "$private_key_size" != "32" ]]; then
    echo "Sparkle EdDSA private key must decode to a 32-byte Ed25519 seed" >&2
    exit 1
fi
if [[ "$public_key_size" != "32" ]]; then
    echo "SPARKLE_PUBLIC_KEY must decode to a 32-byte Ed25519 public key" >&2
    exit 1
fi

# Sparkle's exported modern private-key file is the base64 encoding of the
# Ed25519 seed. Wrap that raw seed in the standard PKCS#8 Ed25519 DER prefix,
# then let OpenSSL derive the public key. Neither key is printed to output.
printf '\060\056\002\001\000\060\005\006\003\053\145\160\004\042\004\040' > "$private_key_der"
cat "$private_key_bytes" >> "$private_key_der"

if ! openssl pkey -inform DER -in "$private_key_der" -pubout -outform DER > "$derived_public_key_der" 2>/dev/null; then
    echo "Sparkle EdDSA private key could not be parsed as an Ed25519 seed" >&2
    exit 1
fi

tail -c 32 "$derived_public_key_der" > "$derived_public_key_bytes"
if ! cmp -s "$public_key_bytes" "$derived_public_key_bytes"; then
    echo "SPARKLE_PUBLIC_KEY does not match SPARKLE_ED_KEY_FILE" >&2
    exit 1
fi

echo "Sparkle EdDSA key pair: ok"
