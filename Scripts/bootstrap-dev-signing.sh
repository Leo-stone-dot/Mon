#!/bin/bash

set -euo pipefail

# Local-development only. Creates a self-signed code signing identity so a build
# keeps a stable code signature across rebuilds, which lets macOS keep the
# Accessibility (TCC) grant instead of invalidating it every build.
#
# Usage: Scripts/bootstrap-dev-signing.sh ["Identity Name"]
# The identity lives under build/signing/ and is not committed.

identity_name=${1:-${SIGN_IDENTITY:-Amethyst Dev}}
slug=$(printf '%s' "$identity_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-')

if [[ "$slug" == "amethyst-dev" ]]; then
    # Preserve the existing local development identity and its TCC grant.
    keychain_name="amethyst-dev"
    password="amethyst"
    key_file="build/signing/key.pem"
    cert_file="build/signing/cert.pem"
    p12_file="build/signing/cert.p12"
else
    keychain_name="$slug"
    password="mon-dev"
    key_file="build/signing/${slug}-key.pem"
    cert_file="build/signing/${slug}-cert.pem"
    p12_file="build/signing/${slug}.p12"
fi

keychain_path="$(pwd)/build/signing/${keychain_name}.keychain-db"

mkdir -p build/signing

if [[ ! -f "$keychain_path" ]]; then
    security create-keychain -p "$password" "$keychain_path"
    security set-keychain-settings -lut 21600 "$keychain_path"
fi

security unlock-keychain -p "$password" "$keychain_path"

if [[ ! -f "$p12_file" ]]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout "$key_file" \
        -out "$cert_file" \
        -days 3650 \
        -nodes \
        -subj "/CN=$identity_name" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

    openssl pkcs12 -export \
        -inkey "$key_file" \
        -in "$cert_file" \
        -out "$p12_file" \
        -passout "pass:$password" \
        -name "$identity_name" \
        -macalg sha1 \
        -certpbe PBE-SHA1-3DES \
        -keypbe PBE-SHA1-3DES
fi

if ! security find-identity -v -p codesigning "$keychain_path" | rg -q "$identity_name"; then
    security import "$p12_file" -k "$keychain_path" -P "$password" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain_path" >/dev/null
    security add-trusted-cert -r trustRoot -p codeSign -k "$keychain_path" "$cert_file"
fi

if ! security list-keychains -d user | rg -qF "$keychain_path"; then
    existing=$(security list-keychains -d user | sed 's/^[[:space:]]*//; s/"//g')
    # shellcheck disable=SC2086
    security list-keychains -d user -s $existing "$keychain_path"
fi

security find-identity -v -p codesigning "$keychain_path"
echo "development signing identity ready: $identity_name"
