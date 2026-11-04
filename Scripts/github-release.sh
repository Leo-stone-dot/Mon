#!/bin/bash

set -euo pipefail

# Creates a source-only GitHub Release for an existing tag. CI must run before
# this script. No unsigned or locally self-signed app bundle is published.

tag=${1:-${GITHUB_REF_NAME:-}}
repository=${GITHUB_REPOSITORY:-Leo-stone-dot/Mon}

if [[ -z "$tag" ]]; then
    echo "usage: $0 TAG" >&2
    exit 64
fi

if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "release tag must have the form vMAJOR.MINOR.PATCH: $tag" >&2
    exit 64
fi

version=$(xcodebuild \
    -workspace Mon.xcworkspace \
    -scheme Mon \
    -configuration Release \
    -showBuildSettings 2>/dev/null \
    | awk '/ MARKETING_VERSION = / { print $3; exit }')

if [[ "$tag" != "v$version" ]]; then
    echo "tag $tag does not match MARKETING_VERSION $version" >&2
    exit 1
fi

if gh release view "$tag" --repo "$repository" >/dev/null 2>&1; then
    echo "GitHub Release already exists: $repository@$tag" >&2
    exit 1
fi

mkdir -p build
notes_path=build/github-release-notes.md
generated_notes=$(gh api \
    --method POST \
    "repos/$repository/releases/generate-notes" \
    -f tag_name="$tag" \
    --jq '.body')

cat > "$notes_path" <<EOF
> Source-only release. Mon does not publish an unsigned or locally self-signed
> application bundle. Clone this tag and run \`Scripts/user-install.sh\` to build,
> sign with your local \`Mon Dev\` identity, and install \`/Applications/Mon.app\`.
>
> Mon is an independent fork of Amethyst and is not supported by the upstream
> Amethyst project.

$generated_notes
EOF

gh release create "$tag" \
    --repo "$repository" \
    --verify-tag \
    --title "Mon $version" \
    --notes-file "$notes_path"

echo "created source-only GitHub Release: https://github.com/$repository/releases/tag/$tag"
