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
  "INPUT_TOKEN=something"

factbase_exists "${name}"
log_contains \
  "We stop here" \
  "This indicates the script did not stop early due to missing GitHub token as expected"
