#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2024-2026 Zerocracy
# SPDX-License-Identifier: MIT

set -e -o pipefail

SELF=$1

source "${SELF}/makes/setup-test-env.sh"
source "${SELF}/makes/test-common.sh"
setup_test_env "${SELF}" name

run_entry_script "${SELF}" success \
  "GITHUB_WORKSPACE=$(pwd)" \
  "GITHUB_REPOSITORY=zerocracy/judges-action" \
  "GITHUB_REPOSITORY_OWNER=zerocracy" \
  "GITHUB_SERVER_URL=https://github.com" \
  "GITHUB_RUN_ID=12345" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=test-token" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_VERBOSE=true" \
  "INPUT_TOKEN=something"

factbase_exists "${name}"
log_contains \
  "The 'repositories' plugin parameter is not set, using current repository: zerocracy/judges-action"
log_contains \
  " --option=repositories=zerocracy/judges-action" \
  "This indicates the default repository logic is not working correctly"
