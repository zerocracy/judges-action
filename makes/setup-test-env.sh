#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2025 Zerocracy
# SPDX-License-Identifier: MIT

# Sets up common test environment and returns a random factbase name
# Usage (preferred): setup_test_env "$1" name
# Backward-compat: still echoes the name to stdout
setup_test_env() {
  set -ex -o pipefail

  local SELF=$1
  local name=$2

  if [ -z "${SELF:-}" ] || [ -z "${name:-}" ]; then
    echo "missing required arguments: SELF='${SELF:-}' name='${name:-}'" >&2
    return 1
  fi

  if [ ! -f "${SELF}/Gemfile" ]; then
    echo "Gemfile not found at ${SELF}/Gemfile" >&2
    return 1
  fi

  declare -g "${name}=$(LC_ALL=C tr -dc '[:lower:]' </dev/urandom | head -c 16 || true)"

  BUNDLE_GEMFILE="${SELF}/Gemfile"
  export BUNDLE_GEMFILE
  bundle exec judges eval "${!name}.fb" "\$fb.insert" > /dev/null
}
