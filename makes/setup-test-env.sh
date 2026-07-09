#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
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

  # Generate random name, ignoring SIGPIPE errors from tr when head closes the pipe
  generated=$(LC_ALL=C tr -dc '[:lower:]' </dev/urandom 2>/dev/null | head -c 16) || true

  if [ -z "${generated}" ]; then
    echo "Failed to generate random name" >&2
    return 1
  fi

  declare -g "${name}=${generated}"

  BUNDLE_GEMFILE="${SELF}/Gemfile"
  export BUNDLE_GEMFILE
  bundle exec judges eval "${!name}.fb" "\$fb.insert" > /dev/null
}
