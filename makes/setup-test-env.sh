#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Sets up common test environment and returns a random factbase name
# Usage: name=$(setup_test_env "$1")
setup_test_env() {
  set -ex -o pipefail

  local SELF=$1

  local name
  name=$(LC_ALL=C tr -dc '[:lower:]' </dev/urandom | head -c 16 || true)

  BUNDLE_GEMFILE="${SELF}/Gemfile"
  export BUNDLE_GEMFILE
  bundle exec judges eval "${name}.fb" "\$fb.insert" > /dev/null

  echo "${name}"
}
