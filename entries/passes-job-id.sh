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
  "GITHUB_RUN_ID=99999" \
  "INPUT_FACTBASE=${name}.fb" \
  "INPUT_CYCLES=1" \
  "INPUT_REPOSITORIES=yegor256/factbase" \
  "INPUT_VERBOSE=false" \
  "INPUT_TOKEN=something" \
  "INPUT_DRY-RUN=true" \
  "INPUT_GITHUB-TOKEN=THETOKEN"

factbase_exists "${name}"
log_contains \
  " --option=job_id=99999" \
  "This indicates the GITHUB_RUN_ID environment variable is not being processed as job_id"
