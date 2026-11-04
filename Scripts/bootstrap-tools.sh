#!/bin/bash

set -euo pipefail

brew bundle install --no-upgrade
mint bootstrap

ruby_bin=$(brew --prefix ruby@3.4)/bin
export PATH="$ruby_bin:$PATH"

BUNDLE_PATH=build/vendor/bundle bundle check || BUNDLE_PATH=build/vendor/bundle bundle install --frozen
