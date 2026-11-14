#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

run_entry_script "${SELF}" failure \
  "GITHUB_WORKSPACE=$(pwd)" \
  "INPUT_DRY-RUN=true" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_GITHUB-TOKEN=something" \
  "INPUT_TIMEOUT=153722867280912931"

log_contains \
  "INPUT_TIMEOUT must be a positive integer" \
  "A timeout too large to turn into seconds must be refused, not multiplied into a negative number"
log_not_contains \
  "Each judge will spend up to -" \
  "This indicates the timeout overflowed into a negative number of seconds"
