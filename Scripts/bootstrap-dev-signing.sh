#!/bin/bash

set -euo pipefail

# Local-development only. Creates a self-signed code signing identity so the
# Debug build keeps a stable code signature across rebuilds, which lets macOS
# keep the Accessibility (TCC) grant instead of invalidating it every build.
#
# The identity lives under build/signing/ and is not committed.

keychain_path="$(pwd)/build/signing/amethyst-dev.keychain-db"
identity_name="Amethyst Dev"

mkdir -p build/signing

if [[ ! -f "$keychain_path" ]]; then
    security create-keychain -p amethyst "$keychain_path"
    security set-keychain-settings -lut 21600 "$keychain_path"
fi

security unlock-keychain -p amethyst "$keychain_path"

if [[ ! -f build/signing/cert.p12 ]]; then
    openssl req -x509 -newkey rsa:2048 \
        -keyout build/signing/key.pem \
        -out build/signing/cert.pem \
        -days 3650 \
        -nodes \
        -subj "/CN=$identity_name" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

    openssl pkcs12 -export \
        -inkey build/signing/key.pem \
        -in build/signing/cert.pem \
        -out build/signing/cert.p12 \
        -passout pass:amethyst \
        -name "$identity_name" \
        -macalg sha1 \
        -certpbe PBE-SHA1-3DES \
        -keypbe PBE-SHA1-3DES
fi

if ! security find-identity -v -p codesigning "$keychain_path" | rg -q "$identity_name"; then
    security import build/signing/cert.p12 -k "$keychain_path" -P amethyst -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k amethyst "$keychain_path" >/dev/null
    security add-trusted-cert -r trustRoot -p codeSign -k "$keychain_path" build/signing/cert.pem
fi

if ! security list-keychains -d user | rg -qF "$keychain_path"; then
    existing=$(security list-keychains -d user | sed 's/^[[:space:]]*//; s/"//g')
    # shellcheck disable=SC2086
    security list-keychains -d user -s $existing "$keychain_path"
fi

security find-identity -v -p codesigning "$keychain_path"
echo "development signing identity ready: $identity_name"
