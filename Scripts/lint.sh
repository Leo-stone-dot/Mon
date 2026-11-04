#!/bin/bash

set -euo pipefail

mint run swiftlint lint --strict --baseline .swiftlint-baseline.json
