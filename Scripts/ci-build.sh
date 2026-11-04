#!/bin/bash

set -euo pipefail

# CI entry point. It never creates a local signing identity, installs an app,
# launches a GUI process, or modifies user settings. Build products are unsigned.

evidence_path=${MON_CI_EVIDENCE_PATH:-build/environment}
Scripts/collect-build-environment.sh "$evidence_path"
Scripts/verify-support-contract.sh
Scripts/verify-toolchain-locks.sh
Scripts/test-release-preflight.sh
Scripts/test-generate-artifact-manifest.sh
Scripts/lint.sh
Scripts/ci-build-and-test.sh
Scripts/test-release-custom-layouts.sh
Scripts/release-pipeline.sh ci

if [[ ${MON_CI_SKIP_GIT_DIFF:-false} != "true" ]]; then
    git diff --exit-code
fi

echo "CI build gates complete"
