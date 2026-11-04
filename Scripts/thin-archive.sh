#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
    echo "usage: $0 APP_BUNDLE" >&2
    exit 64
fi

app_path=$1

while IFS= read -r candidate; do
    if ! file "$candidate" | rg -q 'Mach-O'; then
        continue
    fi

    architectures=$(lipo -archs "$candidate")
    if [[ "$architectures" == "arm64" ]]; then
        continue
    fi

    if ! grep -qw arm64 <<< "$architectures"; then
        echo "Mach-O has no arm64 slice: $candidate ($architectures)" >&2
        exit 1
    fi

    temporary_file=$candidate.amethyst-arm64
    file_mode=$(stat -f '%Lp' "$candidate")
    lipo -thin arm64 "$candidate" -output "$temporary_file"
    chmod "$file_mode" "$temporary_file"
    mv "$temporary_file" "$candidate"
    echo "thinned $candidate: $architectures -> arm64"
done < <(find "$app_path" -type f)
